import java.io.File;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.attribute.BasicFileAttributes;
import java.nio.file.attribute.FileTime;
import java.text.ParseException;
import java.util.ArrayList;
import java.util.Date;
import java.util.HashMap;
import java.util.Properties;
import java.util.Scanner;

public class Listener {
	private static boolean listenerStarted = false;
	public static String osuPath = "";
	public static String audioShieldPath = "";
	public static HashMap<String, Date> songIndex = new HashMap<String, Date>();
	public static String currentlyLoadedMapPath = "";
	public static Scanner scanner = new Scanner(System.in);
	public static String input;

	public static void main(String[] args) throws IOException, ParseException {

		showWelcome();
		showHelp();
		initPaths();

		while (true) {
			input = scanner.nextLine();

			if (input.equals("start") && listenerStarted == false) {
				startListener();
				listenerStarted = true;
			} else if (input.equals("reset"))
				resetProps();
			else if (input.contains("setMaxDif:"))
				setMaxDif(input);
			else if (input.contains("direct:")) {
				String filePath = input.substring(input.indexOf(":") + 1);
				File beatMap = new File(filePath);
				if (beatMap.isFile() && beatMap.getName().contains(".osu")) {
					System.out.println("Loading beatmap: " + beatMap.getName());
					loadBeatmap(beatMap);
				} else {
					System.out.println("Path doesnt direct to a .osu file!");
				}
			} else if (input.equals("help")) {
				showHelp();
			} else if (input.equals("quit")) {
				System.exit(0);
			} else {
				System.out.println("Couldn't recognize input, try again or use \"help\"");
			}

		}

	}

	private static void resetProps() throws ParseException {
		Properties props = new Properties();
		try {
			props.load(Listener.class.getResourceAsStream("paths.properties"));
			props.setProperty("osuPath", "");
			props.setProperty("audioShieldPath", "");
			props.store(new FileOutputStream("resource/paths.properties"), null);
			Thread.sleep(100);
			initPaths();

		} catch (IOException e) {
			e.printStackTrace();
		} catch (InterruptedException e) {
			e.printStackTrace();
		}
	}

	private static void setMaxDif(String difInput) throws FileNotFoundException, IOException {
		
		String maxDif=difInput.substring(difInput.indexOf(":") + 1);
		Properties props = new Properties();
		props.clear();
		try {
			props.load(Listener.class.getResourceAsStream("paths.properties"));
		} catch (IOException e) {
			e.printStackTrace();
		}
		props.setProperty("maxDif", maxDif);
		props.store(new FileOutputStream("resource/paths.properties"), null);
		System.out.println("Max. overall difficulty set to "+ maxDif);

	}

	private static void showHelp() {
		System.out.println("Commands / Usage: \n");
		System.out.println("\"direct:C:\\path\\beatmap.osu\"   -     load a specific beatmap directly");
		System.out.println(
				"\"start\"             -     start the listener, start this before AudioShield to automatically transfer your osu beatmaps to AS");
		System.out.println(
				"\"reset\"             -     asks you to specify the paths to your osu! and Audioshield-mod folders");
		System.out.println("\"setMaxDif:x\"       -      sets the highest Osu Overall Difficulty to x. Default = 10");
		System.out.println("\"help\"              -     shows you this text");
		System.out.println("\"quit\"              -     guess what");
		System.out.println("\n");

	}

	private static void showWelcome() {
		System.out.println("-------------------------------------------------------------------------------");
		System.out.println("----------------------------Osu Listener v0.1----------------------------------");
		System.out.println("-------------------------------------------------------------------------------");
	}

	private static void loadBeatmap(File beatMap) {
		// copy the hitobjects to the VR mod LUA
		ArrayList<String> hitobjects = extractHitObjects(beatMap);
		String meteorNodes = convertBeatmapToLuaNodes(hitobjects);
		insertNodes(meteorNodes);
		System.out.println("Beatmap \"" + beatMap.getName() + "\" loaded!");
		System.out.println("-------------------------------------------------------------------------------");

	}

	private static void insertNodes(String meteorNodes) {

		// use insertion markers in the lua file??
	}

	private static String convertBeatmapToLuaNodes(ArrayList<String> hitobjects) {
		// TODO Auto-generated method stub
		return null;
	}

	private static ArrayList<String> extractHitObjects(File beatMap) {
		// TODO Auto-generated method stub
		return null;
	}

	private static void startListener() throws IOException, ParseException {
		System.out.println("---------------------------------------------------------------------------");
		System.out.println("---------------Listener Started---------------------");
		initialIndexing();
		System.out.println("---------------Starting Listening--------------------");

		Runnable keyPressThread = new ListenerThread();
		Thread listenerThread = new Thread(keyPressThread);
		listenerThread.start();

	}

	public static class ListenerThread implements Runnable {

		Scanner inputReader = new Scanner(System.in);

		// Method that gets called when the object is instantiated
		public ListenerThread() {
		}

		public void run() {
			try {
				updatemap();
			} catch (IOException e) {
				e.printStackTrace();
			} catch (ParseException e) {
				e.printStackTrace();
			}
		}

	}

	private static void updatemap() throws IOException, ParseException {
		// System.out.println(new Date() + " starting listening loop");
		for (String filePath : songIndex.keySet()) {
			String songFolder = filePath.substring(0, filePath.lastIndexOf("\\"));
			Date lastAccess = ask4lastAccess(filePath);

			if (!lastAccess.equals(songIndex.get(filePath))) {
				// this mp3 was accessed!
				songIndex.put(filePath, lastAccess);
				if (currentlyLoadedMapPath != filePath) {
					System.out.println(lastAccess + " Loading MP3 : " + filePath
							.substring(filePath.substring(0, filePath.lastIndexOf("\\") - 1).lastIndexOf("\\")));
					currentlyLoadedMapPath = filePath;
				}
			}
		}
		// System.out.println(new Date() + " ended listening loop");
	}

	private static Date ask4lastAccess(String filePath) throws IOException, ParseException {
		Path file = Paths.get(filePath);
		FileTime time = Files.readAttributes(file, BasicFileAttributes.class).lastAccessTime();
		Date date = new Date(time.toMillis());
		return date;
	}

	private static void initialIndexing() throws IOException, ParseException {

		File f = new File(osuPath);
		System.out.println(new Date() + " starting initial indexing!");

		songIndex = findDirectory(f);
		System.out.println(new Date() + " Indexed " + songIndex.size() + " songs!");

	}

	private static HashMap<String, Date> findDirectory(File parentDirectory) throws IOException, ParseException {
		File[] files = parentDirectory.listFiles();
		for (File file : files) {
			if (file.getName().contains(".mp3")) {
				songIndex.put(file.getAbsolutePath(), ask4lastAccess(file.getAbsolutePath()));
			}
			if (file.isDirectory()) {
				findDirectory(file);
			}
		}
		return songIndex;
	}

	private static void initPaths() throws FileNotFoundException, IOException, ParseException {

		Properties props = new Properties();
		props.clear();
		try {
			props.load(Listener.class.getResourceAsStream("paths.properties"));
		} catch (IOException e) {
			e.printStackTrace();
		}
		osuPath = props.getProperty("osuPath").toString();
		audioShieldPath = props.getProperty("audioShieldPath").toString();

		System.out.println("Path to Osu! Songs folder = " + osuPath);
		System.out.println("Path to the Osu! Audioshield Mod Folder = " + audioShieldPath);
		System.out.println("---------------------------------------------------------------------------");

		if (osuPath.isEmpty() || audioShieldPath.isEmpty()) {
			System.out.println("Please set the paths correctly using following syntax: ");
			System.out.println("\"c:\\yourpath\\here");
			if (osuPath.isEmpty()) {
				String input = "";
				while (!new File(input).isDirectory()) {
					System.out.println("Please enter your osuPath: ");
					input = scanner.nextLine();
					if (new File(input).isDirectory()) {
						props.setProperty("osuPath", input);
					} else
						System.out.println("Not a valid dir!");
				}

			}
			if (audioShieldPath.isEmpty()) {
				String input = "";
				while (!new File(input).isDirectory()) {
					System.out.println("Please enter your audioShieldPath: ");
					input = scanner.nextLine();
					if (new File(input).isDirectory()) {
						props.setProperty("audioShieldPath", input);
					} else
						System.out.println("Not a valid dir!");
				}

			}
			props.store(new FileOutputStream("resource/paths.properties"), null);
		}
	}
}
