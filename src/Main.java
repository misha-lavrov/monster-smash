import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpServer;

import java.io.IOException;
import java.net.BindException;
import java.net.InetAddress;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.InvalidPathException;
import java.nio.file.Path;
import java.util.List;
import java.util.concurrent.ThreadLocalRandom;
import java.util.stream.Stream;

/**
 * ⚔️ «ПОБИЙ МОНСТРА!» — міні-гра для майстер-класу ОІПЗ.
 *
 * Як це працює:
 *   • Браузер  = «обличчя» гри. Він малює монстра й кнопку (папка web/).
 *   • Цей файл = «мозок» гри. Java-сервер рахує удари й пам'ятає здоров'я монстра.
 *
 * Браузер питає — Java відповідає. Так працює майже кожен сайт і додаток.
 *
 * Запуск: натисни зелений ▶ біля слова main (в IntelliJ) або start.bat
 */
public class Main {

    // =====================================================================
    //  1. НАЛАШТУВАННЯ ГРИ  —  міняй і дивись, що вийде!
    //     Змінив → натисни ▶ (Rerun) → сторінка в браузері оновиться сама.
    // =====================================================================

    static final String HERO_NAME   = "Герой";   // ✏️ Впиши сюди своє ім'я
    static final int    DAMAGE_MIN  = 5;         // ✏️ Найслабший удар
    static final int    DAMAGE_MAX  = 15;        // ✏️ Найсильніший удар
    static final int    CRIT_CHANCE = 20;        // ✏️ Шанс критичного удару, % (від 0 до 100). Крит б'є вдвічі сильніше!

    // ✏️ Монстри: смайлик, ім'я, здоров'я. Хочеш свого монстра — скопіюй рядок і зміни!
    //    Увага: після кожного рядка, КРІМ ОСТАННЬОГО, має стояти кома.
    static final List<Monster> MONSTERS = List.of(
            new Monster("🐉", "Дракон",    100),
            new Monster("🧟", "Зомбі",     150),
            new Monster("👾", "Прибулець", 200)
    );

    /** Що таке «монстр»: смайлик, ім'я та здоров'я. */
    record Monster(String emoji, String name, int hp) { }


    /** Звідси програма починає працювати. Натисни ▶ зліва від цього рядка! */
    public static void main(String[] args) throws IOException {
        int port = args.length > 0 ? Integer.parseInt(args[0]) : 8765;
        startGame();            // готуємо гру: перший монстр із повним здоров'ям
        startWebServer(port);   // відкриваємо «віконце» для браузера (див. розділ 3)
    }


    // =====================================================================
    //  2. МОЗОК ГРИ  —  тут сервер вирішує, що відбувається
    // =====================================================================

    static int  monsterNo;   // який монстр зараз у бою (номер у списку MONSTERS)
    static long hp;          // скільки здоров'я лишилось у цього монстра
    static int  kills;       // скільки монстрів уже переможено

    static void startGame() {
        if (MONSTERS.isEmpty()) {
            System.out.println("ПОМИЛКА: список монстрів порожній. Додай хоча б одного!");
            System.exit(1);
        }
        monsterNo = 0;
        kills = 0;
        hp = maxHp();
    }

    /** Гравець вдарив! Рахуємо шкоду й дивимось, чи монстр ще живий. Повертає відповідь для браузера. */
    static String hit() {
        long damage = Math.max(1, randomBetween(DAMAGE_MIN, DAMAGE_MAX));   // випадкова сила удару
        boolean crit = randomBetween(1, 100) <= CRIT_CHANCE;                // чи пощастило з критом?
        if (crit) {
            damage = damage * 2;                                            // крит = подвійна шкода
        }

        hp = hp - damage;                                                   // віднімаємо здоров'я
        System.out.println("Удар: " + damage + (crit ? " (КРИТ!)" : "")
                + "  ->  " + current().name() + ", лишилось " + Math.max(hp, 0) + " HP");

        boolean killed = hp <= 0;                                           // монстр помер?
        if (killed) {
            kills = kills + 1;                                              // +1 перемога
            monsterNo = (monsterNo + 1) % MONSTERS.size();                  // наступний монстр зі списку
            hp = maxHp();                                                   // у нового — повне здоров'я
            System.out.println("Монстра переможено! Наступний: " + current().name());
        }

        return "{\"damage\":" + damage
                + ",\"crit\":" + crit
                + ",\"killed\":" + killed
                + ",\"state\":" + stateJson() + "}";
    }

    /** Усе, що браузеру треба знати, щоб намалювати гру (у форматі JSON). */
    static String stateJson() {
        Monster m = current();
        return "{\"hero\":" + quote(HERO_NAME)
                + ",\"kills\":" + kills
                + ",\"hp\":" + Math.max(hp, 0)
                + ",\"monster\":{\"emoji\":" + quote(m.emoji())
                + ",\"name\":" + quote(m.name())
                + ",\"maxHp\":" + maxHp() + "}}";
    }

    static Monster current() {
        return MONSTERS.get(monsterNo);
    }

    static int maxHp() {
        return Math.max(1, current().hp());
    }

    /** Випадкове число від a до b (включно). */
    static int randomBetween(int a, int b) {
        long low = Math.min(a, b);
        long high = Math.max(a, b);
        return (int) ThreadLocalRandom.current().nextLong(low, high + 1);
    }


    // <editor-fold desc="3. 🔌 ТРУБИ — зв'язок із браузером (технічна частина, її не чіпаємо)" defaultstate="collapsed">
    // =====================================================================
    //  3. ТРУБИ  —  як браузер розмовляє з Java (можна не читати 🙂)
    //     Сервер слухає тільки цей комп'ютер (localhost), ззовні до нього не достукатись.
    // =====================================================================

    static final long STARTED_AT = System.currentTimeMillis();
    static Path webDir;

    static void startWebServer(int port) throws IOException {
        webDir = findWebDir();

        HttpServer server;
        try {
            server = HttpServer.create(new InetSocketAddress(InetAddress.getLoopbackAddress(), port), 0);
        } catch (BindException e) {
            System.out.println("ПОМИЛКА: порт " + port + " зайнятий — схоже, сервер уже запущено.");
            System.out.println("Зупини старий (червоний квадрат ■ в IntelliJ або stop.bat) і запусти ще раз.");
            System.exit(1);
            return;
        }

        // «Адреси», за якими браузер може звертатись до сервера:
        server.createContext("/api/state",   ex -> sendJson(ex, stateJson()));      // що зараз у грі?
        server.createContext("/api/version", ex -> sendJson(ex, versionJson()));    // чи не змінився код? (для автооновлення)
        server.createContext("/api/hit", ex -> {                                    // вдарити монстра
            if (!"POST".equals(ex.getRequestMethod())) {
                send(ex, 405, "text/plain; charset=utf-8", "Удар робиться запитом POST (кнопка в грі).".getBytes(StandardCharsets.UTF_8));
                return;
            }
            sendJson(ex, hit());
        });
        server.createContext("/", Main::sendFile);                                  // усе інше — файли з папки web/

        server.start();
        System.out.println("=================================================");
        System.out.println("  Сервер запущено!  Відкрий у браузері:");
        System.out.println("  http://localhost:" + port);
        System.out.println("=================================================");
    }

    /** Віддає файл із папки web/ (index.html, style.css, app.js ...). */
    static void sendFile(HttpExchange ex) throws IOException {
        String path = ex.getRequestURI().getPath();
        if (path.equals("/")) {
            path = "/index.html";
        }
        try {
            Path file = webDir.resolve(path.substring(1)).normalize();
            if (file.startsWith(webDir) && Files.isRegularFile(file)) {
                send(ex, 200, contentType(file.getFileName().toString()), Files.readAllBytes(file));
                return;
            }
        } catch (InvalidPathException ignored) {
            // дивна адреса — просто скажемо «404»
        }
        send(ex, 404, "text/plain; charset=utf-8", "404 — такої сторінки немає".getBytes(StandardCharsets.UTF_8));
    }

    /**
     * «Відбиток версії»: час запуску сервера + час останньої зміни файлів у web/.
     * Сторінка в браузері раз на секунду питає його — і сама оновлюється, коли він змінився.
     */
    static String versionJson() throws IOException {
        long newest = 0;
        try (Stream<Path> files = Files.walk(webDir)) {
            newest = files.mapToLong(Main::modifiedAt).max().orElse(0);
        }
        return "{\"version\":\"" + STARTED_AT + "-" + newest + "\"}";
    }

    static long modifiedAt(Path p) {
        try {
            return Files.getLastModifiedTime(p).toMillis();
        } catch (IOException e) {
            return 0;
        }
    }

    static Path findWebDir() {
        Path dir = Path.of("").toAbsolutePath();
        for (int i = 0; i < 4 && dir != null; i++) {
            Path candidate = dir.resolve("web");
            if (Files.exists(candidate.resolve("index.html"))) {
                return candidate.normalize();
            }
            dir = dir.getParent();
        }
        System.out.println("ПОМИЛКА: не знаю, де папка web. Запускай гру з папки проєкту (monster-smash).");
        System.exit(1);
        return null;
    }

    static void sendJson(HttpExchange ex, String json) throws IOException {
        send(ex, 200, "application/json; charset=utf-8", json.getBytes(StandardCharsets.UTF_8));
    }

    static void send(HttpExchange ex, int status, String type, byte[] body) throws IOException {
        ex.getResponseHeaders().set("Content-Type", type);
        ex.getResponseHeaders().set("Cache-Control", "no-store");   // щоб браузер не показував старе
        ex.sendResponseHeaders(status, body.length);
        ex.getResponseBody().write(body);
        ex.close();
    }

    static String contentType(String fileName) {
        String f = fileName.toLowerCase();
        if (f.endsWith(".html"))  return "text/html; charset=utf-8";
        if (f.endsWith(".css"))   return "text/css; charset=utf-8";
        if (f.endsWith(".js"))    return "text/javascript; charset=utf-8";
        if (f.endsWith(".json"))  return "application/json; charset=utf-8";
        if (f.endsWith(".svg"))   return "image/svg+xml";
        if (f.endsWith(".png"))   return "image/png";
        if (f.endsWith(".jpg") || f.endsWith(".jpeg")) return "image/jpeg";
        if (f.endsWith(".gif"))   return "image/gif";
        if (f.endsWith(".ico"))   return "image/x-icon";
        return "application/octet-stream";
    }

    /** Загортає текст у лапки для JSON (екранує лапки, слеші та переноси рядків). */
    static String quote(String s) {
        StringBuilder sb = new StringBuilder("\"");
        for (char c : s.toCharArray()) {
            switch (c) {
                case '"'  -> sb.append("\\\"");
                case '\\' -> sb.append("\\\\");
                case '\n' -> sb.append("\\n");
                case '\r' -> sb.append("\\r");
                case '\t' -> sb.append("\\t");
                default   -> sb.append(c < 0x20 ? String.format("\\u%04x", (int) c) : String.valueOf(c));
            }
        }
        return sb.append('"').toString();
    }
    // </editor-fold>
}
