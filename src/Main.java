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
import java.util.concurrent.TimeUnit;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import java.util.stream.Stream;

/**
 * <h2>⚔️ «Побий монстра!»</h2>
 *
 * <p>Міні-гра для майстер-класу ОІПЗ. Вона складається з двох половинок:</p>
 * <ul>
 *   <li><b>Браузер</b> — «обличчя» гри: малює монстра й кнопку (папка {@code web/}).</li>
 *   <li><b>Цей файл</b> — «мозок» гри: Java-сервер, який рахує удари й пам'ятає здоров'я монстра.</li>
 * </ul>
 *
 * <p>Браузер <b>питає</b> — Java <b>відповідає</b>. Так працює майже кожен сайт і застосунок.</p>
 *
 * <p>У файлі три розділи: <b>1. Налаштування</b> (їх ми міняємо), <b>2. Мозок гри</b> (правила),
 * <b>3. Труби</b> (технічний зв'язок із браузером — його можна не читати).</p>
 *
 * <p>Запуск: зелений ▶ біля слова {@code main} в IntelliJ або {@code start.bat}.</p>
 */
public class Main {

    // =====================================================================
    //  1. НАЛАШТУВАННЯ ГРИ — міняй і дивись, що вийде!
    //     Змінив → натисни ▶ (Rerun) → сторінка в браузері оновиться сама.
    // =====================================================================

    /** ✏️ Ім'я героя. Його видно в заголовку гри — впиши своє! */
    static final String HERO_NAME = "Герой";

    /** ✏️ Найслабший удар героя: стільки здоров'я монстр втратить щонайменше. */
    static final int DAMAGE_MIN = 5;

    /** ✏️ Найсильніший удар героя. Справжній удар — випадкове число від {@link #DAMAGE_MIN} до цього значення. */
    static final int DAMAGE_MAX = 15;

    /** ✏️ Шанс критичного удару у відсотках (від 0 до 100). Крит б'є вдвічі сильніше! */
    static final int CRIT_CHANCE = 20;

    /**
     * ✏️ Усі монстри гри: смайлик, ім'я, здоров'я. Вони виходять на бій по черзі, а після останнього знову йде перший.
     *
     * <p>Хочеш свого монстра — скопіюй рядок і зміни. Після кожного рядка, <b>крім останнього</b>, має стояти кома!</p>
     */
    static final List<Monster> MONSTERS = List.of(
            new Monster("🐉", "Дракон",    100),
            new Monster("🧟", "Зомбі",     150),
            new Monster("👾", "Прибулець", 200)
    );

    /**
     * Один монстр.
     *
     * @param emoji смайлик, який малює браузер
     * @param name  ім'я під смайликом
     * @param hp    скільки здоров'я в монстра на початку бою
     */
    record Monster(String emoji, String name, int hp) { }


    /**
     * Точка входу: звідси програма починає працювати. <b>Натисни ▶ зліва від цього рядка!</b>
     *
     * @param args необов'язковий номер порту; без нього гра слухає порт 8765
     * @throws IOException якщо не вдалося запустити веб-сервер
     */
    public static void main(String[] args) throws IOException {
        int port = args.length > 0 ? Integer.parseInt(args[0]) : 8765;
        startGame();            // готуємо гру: перший монстр із повним здоров'ям
        startWebServer(port);   // відкриваємо «віконце» для браузера (див. розділ 3)
    }


    // =====================================================================
    //  2. МОЗОК ГРИ — тут сервер вирішує, що відбувається
    // =====================================================================

    /** Номер монстра, який зараз у бою (позиція в списку {@link #MONSTERS}). */
    static int monsterNo;

    /** Скільки здоров'я лишилось у поточного монстра. */
    static long hp;

    /** Скільки монстрів уже переможено. */
    static int kills;

    /** Готує нову гру: перший монстр, повне здоров'я, нуль перемог. */
    static void startGame() {
        if (MONSTERS.isEmpty()) {
            System.out.println("ПОМИЛКА: список монстрів порожній. Додай хоча б одного!");
            System.exit(1);
        }
        monsterNo = 0;
        kills = 0;
        hp = maxHp();
    }

    /**
     * Гравець вдарив! Рахуємо шкоду і дивимось, чи монстр ще живий.
     *
     * <ol>
     *   <li>Випадкова сила удару — від {@link #DAMAGE_MIN} до {@link #DAMAGE_MAX}.</li>
     *   <li>З шансом {@link #CRIT_CHANCE} % удар критичний, і шкода подвоюється.</li>
     *   <li>Віднімаємо шкоду від здоров'я. Здоров'я закінчилось — монстр переможений, виходить наступний.</li>
     * </ol>
     *
     * @return відповідь для браузера у форматі JSON: шкода, чи був крит, чи вбито монстра, і новий стан гри
     */
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

    /**
     * Усе, що браузеру треба знати, щоб намалювати гру: ім'я героя, перемоги, здоров'я та поточний монстр.
     *
     * @return стан гри у форматі JSON
     */
    static String stateJson() {
        Monster m = current();
        return "{\"hero\":" + quote(HERO_NAME)
                + ",\"kills\":" + kills
                + ",\"hp\":" + Math.max(hp, 0)
                + ",\"monster\":{\"emoji\":" + quote(m.emoji())
                + ",\"name\":" + quote(m.name())
                + ",\"maxHp\":" + maxHp() + "}}";
    }

    /**
     * Поточний монстр.
     *
     * @return монстр зі списку {@link #MONSTERS} під номером {@link #monsterNo}
     */
    static Monster current() {
        return MONSTERS.get(monsterNo);
    }

    /**
     * Повне здоров'я поточного монстра (але не менше 1, щоб бій завжди можна було закінчити).
     *
     * @return максимальне здоров'я
     */
    static int maxHp() {
        return Math.max(1, current().hp());
    }

    /**
     * Випадкове число з проміжку між {@code a} і {@code b} (обидва кінці включно).
     * Порядок чисел неважливий: {@code randomBetween(15, 5)} працює так само, як {@code randomBetween(5, 15)}.
     *
     * @param a перша межа
     * @param b друга межа
     * @return випадкове число від меншої межі до більшої
     */
    static int randomBetween(int a, int b) {
        long low = Math.min(a, b);
        long high = Math.max(a, b);
        return (int) ThreadLocalRandom.current().nextLong(low, high + 1);
    }


    // <editor-fold desc="3. 🔌 ТРУБИ — зв'язок із браузером (технічна частина, її не чіпаємо)" defaultstate="collapsed">
    // =====================================================================
    //  3. ТРУБИ — як браузер розмовляє з Java (можна не читати 🙂)
    //     Сервер слухає тільки цей комп'ютер (localhost): ззовні до нього не достукатись.
    // =====================================================================

    /** Момент запуску сервера. Разом із часом змін файлів утворює «версію» для автооновлення сторінки. */
    static final long STARTED_AT = System.currentTimeMillis();

    /** Папка {@code web/} зі сторінкою гри. */
    static Path webDir;

    /** Порт цього сервера. Від нього залежить ім'я файла з номером процесу: у кожного порту свій файл. */
    static int serverPort;

    /** Коли сторінка гри востаннє питала про версію (мілісекунди). Так сервер знає, чи відкрито гру в браузері. */
    static volatile long pageSeenAt;

    /** Так виглядає прапорець у файлі {@code web/index.html}: {@code OIPZ{...}}. */
    static final Pattern FLAG_PATTERN = Pattern.compile("OIPZ\\{[^}\\s]+}");

    /**
     * Запускає веб-сервер і розкладає «адреси» (шляхи), за якими до нього звертається браузер.
     *
     * @param port номер порту
     * @throws IOException якщо сервер не вдалося запустити
     */
    static void startWebServer(int port) throws IOException {
        serverPort = port;
        webDir = findWebDir();

        HttpServer server;
        try {
            server = bindWithTakeover(port);
        } catch (BindException e) {
            System.out.println("ПОМИЛКА: порт " + port + " зайнятий іншою програмою.");
            System.out.println("Зупини її (або stop.bat) і запусти гру ще раз.");
            System.exit(1);
            return;
        }
        writePidFile();

        // «Адреси», за якими браузер може звертатись до сервера:
        server.createContext("/api/state", ex -> sendJson(ex, stateJson()));       // що зараз у грі?
        server.createContext("/api/version", ex -> {                               // чи не змінився код? (автооновлення)
            if ("page=1".equals(ex.getRequestURI().getQuery())) {
                pageSeenAt = System.currentTimeMillis();                           // це питає сама сторінка гри
            }
            sendJson(ex, versionJson());
        });
        server.createContext("/api/pages", ex ->                                   // чи відкрито сторінку гри? (для start.bat)
                sendJson(ex, "{\"open\":" + (System.currentTimeMillis() - pageSeenAt < 2500) + "}"));
        server.createContext("/api/hit", ex -> {                                   // вдарити монстра
            if (!"POST".equals(ex.getRequestMethod())) {
                sendText(ex, 405, "Удар робиться запитом POST (кнопка в грі).");
                return;
            }
            sendJson(ex, hit());
        });
        server.createContext("/api/flag", ex -> {                                  // здати прапорець
            if (!"POST".equals(ex.getRequestMethod())) {
                sendText(ex, 405, "Прапорець здається запитом POST (форма внизу гри).");
                return;
            }
            String answer = new String(ex.getRequestBody().readNBytes(300), StandardCharsets.UTF_8).trim();
            boolean ok = checkFlag(answer);
            System.out.println(ok ? "ПРАПОРЕЦЬ ЗНАЙДЕНО! Хтось розв'язав CTF-завдання." : "Прапорець не збігся — спроба невдала.");
            sendJson(ex, "{\"ok\":" + ok + "}");
        });
        server.createContext("/", Main::sendFile);                                 // усе інше — файли з папки web/

        server.start();
        System.out.println("=================================================");
        System.out.println("  Сервер запущено!  Відкрий у браузері:");
        System.out.println("  http://localhost:" + port);
        System.out.println("=================================================");
    }

    /**
     * Займає порт. Якщо він зайнятий нашим же «старим» сервером (наприклад, запущеним скриптом {@code start.bat}),
     * зупиняє старий і займає порт сам. Завдяки цьому зелений ▶ в IntelliJ працює завжди.
     *
     * @param port номер порту
     * @return готовий (ще не запущений) сервер
     * @throws IOException {@link BindException}, якщо порт зайнятий чимось стороннім
     */
    static HttpServer bindWithTakeover(int port) throws IOException {
        InetSocketAddress address = new InetSocketAddress(InetAddress.getLoopbackAddress(), port);
        try {
            return HttpServer.create(address, 0);
        } catch (BindException busy) {
            if (!stopOldServer()) {
                throw busy;
            }
            for (int attempt = 0; attempt < 10; attempt++) {                       // Windows звільняє порт не миттєво
                try {
                    return HttpServer.create(address, 0);
                } catch (BindException stillBusy) {
                    pause(300);
                }
            }
            throw busy;
        }
    }

    /**
     * Зупиняє попередній екземпляр гри на цьому ж порту. Його номер процесу записано у файл {@code .server-<порт>.pid};
     * зупиняємо тільки якщо це справді Java-процес із нашою програмою {@code Main}.
     *
     * @return {@code true}, якщо старий сервер знайдено й зупинено
     */
    static boolean stopOldServer() {
        try {
            Path pidFile = pidFile();
            if (!Files.exists(pidFile)) {
                return false;
            }
            long pid = Long.parseLong(Files.readString(pidFile).trim());
            if (pid == ProcessHandle.current().pid()) {
                return false;
            }
            ProcessHandle old = ProcessHandle.of(pid).orElse(null);
            if (old == null || !looksLikeOurServer(old)) {
                return false;
            }
            old.destroyForcibly();
            old.onExit().get(5, TimeUnit.SECONDS);
            return true;
        } catch (Exception e) {
            return false;
        }
    }

    /**
     * Перевіряє, що процес — це Java із класом {@code Main} (а не випадкова програма з таким самим номером).
     *
     * @param process процес, який збираємось зупинити
     * @return {@code true}, якщо це схоже на наш сервер
     */
    static boolean looksLikeOurServer(ProcessHandle process) {
        boolean isJava = process.info().command().map(c -> c.toLowerCase().contains("java")).orElse(false);
        boolean isMain = process.info().commandLine().map(c -> c.contains("Main")).orElse(true);
        return isJava && isMain;
    }

    /** Записує номер нашого процесу у {@code .server-<порт>.pid}, щоб наступний запуск міг нас замінити. */
    static void writePidFile() {
        try {
            Files.writeString(pidFile(), String.valueOf(ProcessHandle.current().pid()));
        } catch (IOException ignored) {
            // не вийшло записати — не страшно, просто не буде «перехоплення порту»
        }
    }

    /**
     * Де лежить файл з номером процесу. Для кожного порту — свій файл, щоб тимчасовий сервер
     * (наприклад, з {@code check.bat} на порту 8799) не затирав запис справжньої гри.
     *
     * @return шлях до {@code .server-<порт>.pid} у корені проєкту
     */
    static Path pidFile() {
        return webDir.getParent().resolve(".server-" + serverPort + ".pid");
    }

    /**
     * Перевіряє прапорець. Справжній прапорець зашито в коментарі {@code web/index.html}; сервер читає його звідти,
     * тож змінити прапорець можна в одному місці. (У справжньому CTF прапорець знає лише сервер.)
     *
     * @param answer те, що ввела дитина
     * @return {@code true}, якщо це справжній прапорець
     */
    static boolean checkFlag(String answer) {
        try {
            String html = Files.readString(webDir.resolve("index.html"), StandardCharsets.UTF_8);
            Matcher flag = FLAG_PATTERN.matcher(html);
            return flag.find() && flag.group().equals(answer);
        } catch (IOException e) {
            return false;
        }
    }

    /**
     * Віддає файл із папки {@code web/} (index.html, style.css, app.js ...). Усе, що за межами папки, — «404».
     *
     * @param ex запит браузера
     * @throws IOException якщо не вдалося надіслати відповідь
     */
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
        sendText(ex, 404, "404 — такої сторінки немає");
    }

    /**
     * «Відбиток версії»: час запуску сервера + час останньої зміни файлів у {@code web/}.
     * Сторінка в браузері раз на півсекунди питає його й сама оновлюється, коли він змінився.
     *
     * @return версія у форматі JSON
     * @throws IOException якщо не вдалося прочитати папку {@code web/}
     */
    static String versionJson() throws IOException {
        long newest = 0;
        try (Stream<Path> files = Files.walk(webDir)) {
            newest = files.mapToLong(Main::modifiedAt).max().orElse(0);
        }
        return "{\"version\":\"" + STARTED_AT + "-" + newest + "\"}";
    }

    /**
     * Коли файл змінювали востаннє.
     *
     * @param p шлях до файлу
     * @return час у мілісекундах (0, якщо не вдалося дізнатись)
     */
    static long modifiedAt(Path p) {
        try {
            return Files.getLastModifiedTime(p).toMillis();
        } catch (IOException e) {
            return 0;
        }
    }

    /**
     * Шукає папку {@code web/}: у поточній папці, а якщо там немає — у батьківських (до трьох рівнів угору).
     *
     * @return шлях до папки {@code web/}
     */
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

    /**
     * Надсилає браузеру JSON.
     *
     * @param ex   запит браузера
     * @param json текст відповіді
     * @throws IOException якщо не вдалося надіслати відповідь
     */
    static void sendJson(HttpExchange ex, String json) throws IOException {
        send(ex, 200, "application/json; charset=utf-8", json.getBytes(StandardCharsets.UTF_8));
    }

    /**
     * Надсилає браузеру простий текст (наприклад, повідомлення про помилку).
     *
     * @param ex     запит браузера
     * @param status код відповіді (404 — «не знайдено», 405 — «так не можна»)
     * @param text   текст відповіді
     * @throws IOException якщо не вдалося надіслати відповідь
     */
    static void sendText(HttpExchange ex, int status, String text) throws IOException {
        send(ex, status, "text/plain; charset=utf-8", text.getBytes(StandardCharsets.UTF_8));
    }

    /**
     * Надсилає відповідь: код, тип вмісту й самі дані.
     *
     * @param ex     запит браузера
     * @param status код відповіді (200 — «все добре»)
     * @param type   тип вмісту, наприклад {@code text/html}
     * @param body   дані відповіді
     * @throws IOException якщо не вдалося надіслати відповідь
     */
    static void send(HttpExchange ex, int status, String type, byte[] body) throws IOException {
        ex.getResponseHeaders().set("Content-Type", type);
        ex.getResponseHeaders().set("Cache-Control", "no-store");   // щоб браузер не показував старе
        ex.sendResponseHeaders(status, body.length);
        ex.getResponseBody().write(body);
        ex.close();
    }

    /**
     * Визначає тип вмісту за закінченням імені файлу.
     *
     * @param fileName ім'я файлу
     * @return тип вмісту для браузера
     */
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

    /**
     * Загортає текст у лапки для JSON: екранує лапки, зворотні слеші та переноси рядків.
     *
     * @param s звичайний текст
     * @return текст у лапках, безпечний для JSON
     */
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

    /**
     * Чекає вказаний час.
     *
     * @param millis скільки мілісекунд чекати
     */
    static void pause(long millis) {
        try {
            Thread.sleep(millis);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
    }
    // </editor-fold>
}
