import java.io.BufferedReader;
import java.io.File;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStreamReader;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.attribute.BasicFileAttributes;
import java.nio.file.attribute.FileTime;
import java.text.ParseException;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Date;
import java.util.HashMap;
import java.util.Locale;
import java.util.Properties;
import java.util.Scanner;

public class Listener {
	private static final SimpleDateFormat SIMPLE_DATE_FORMAT = new SimpleDateFormat("dd.MM.yyyy hh:mm:ss",
			Locale.getDefault());
	public static String osuPath = "";
	public static String audioShieldPath = "";
	public static HashMap<String, Date> songIndex = new HashMap<String, Date>();
	public static String currentlyLoadedMapPath = "";

	public static void main(String[] args) throws IOException, ParseException {

		initPaths();

		// // String command = "powershell.exe your command";
		// // Getting the version
		// String command = "powershell.exe \"ls\"";
		// // Executing the command
		// Process powerShellProcess = Runtime.getRuntime().exec(command);
		// // Getting the results
		// powerShellProcess.getOutputStream().close();
		// String line;
		// System.out.println("Standard Output:");
		// BufferedReader stdout = new BufferedReader(new InputStreamReader(
		// powerShellProcess.getInputStream()));
		// while ((line = stdout.readLine()) != null) {
		// System.out.println(line);
		// }
		// stdout.close();
		// System.out.println("Standard Error:");
		// BufferedReader stderr = new BufferedReader(new InputStreamReader(
		// powerShellProcess.getErrorStream()));
		// while ((line = stderr.readLine()) != null) {
		// System.out.println(line);
		// }
		// stderr.close();
		// System.out.println("Done");

	}

	private static void showMenu() throws IOException, ParseException {
		Scanner scanner = new Scanner(new InputStreamReader(System.in));
		System.out.println(
				"type \"start\" to start listener or type \"reset\" to reset paths or use \"direct:Beatmap/Path\" to access a specific beatmap directly");
		String input = scanner.nextLine();
		if (input.contains("start")) {
			scanner.close();
			startListener();
		} else if (input.contains("reset")) {
			Properties props = new Properties();
			try {
				scanner.close();
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
		} else if (input.contains("direct")) {
			String filePath = input.substring(input.indexOf(":") + 1);
			File beatMap = new File(filePath);
			if (beatMap.isFile() && beatMap.getName().contains(".osu")){
			System.out.println("Loading beatmap: " + beatMap.getName());
			loadBeatmap(beatMap);
			showMenu();
			}
			else {
				System.out.println("Path doesnt direct to a .osu file!");
				showMenu();
			}
		} else {
			System.out.println("Couldn't recognize input, try again");
			showMenu();
		}
	}

	private static void loadBeatmap(File beatMap) {
		// copy the hitobjects to the VR mod LUA
		ArrayList<String> hitobjects = extractHitObjects(beatMap);
		String meteorNodes = convertBeatmapToLuaNodes(hitobjects);
		insertNodes(meteorNodes);
		System.out.println("Beatmap \""+ beatMap.getName() + "\" loaded!");
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
		System.out.println("---------------Started Listening---------------------");

		while (true) {
			updatemap();
		}

	}

	private static void updatemap() throws IOException, ParseException {
		//System.out.println(new Date() + " starting listening loop");

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
		//System.out.println(new Date() + " ended listening loop");
	}

	private static Date ask4lastAccess(String filePath) throws IOException, ParseException {
//
//		// String command = "powershell.exe your command";
//		// Getting the version
//		// filePath = escapeSpecialChars(filePath);
//
//		// try( PrintWriter out = new PrintWriter( "C:\\Temp\\path.txt" ) ){
//		// out.println(filePath);
//		// }
//
//		// String command0 = "powershell.exe " + "$string = @\'" + "`\n" +
//		// filePath + "`\nst" + "\'@";
//		String command = "powershell.exe " + "get-date $(Get-Item -literalpath \'" + filePath
//				+ "\').lastaccesstime -format \'dd.MM.yyyy hh:mm:ss\'";
//				// String command = "powershell.exe " + "get-date $(Get-Item
//				// -literalpath (gc 'C:\\Temp\\path.txt')).lastaccesstime
//				// -format \'dd.MM.yyyy hh:mm:ss\'";
//
//		// System.out.println(command);
//		// System.out.println(command1);
//		// Executing the command
//		Process powerShellProcess = Runtime.getRuntime().exec(command);
//		// Process powerShellProcess = Runtime.getRuntime().exec(command1);
//		// Getting the results
//		powerShellProcess.getOutputStream().close();
//		String lineOutput;
//		String lineError;
//		String formattedDate = null;
//		// System.out.println("Standard Output:");
//		BufferedReader stdout = new BufferedReader(new InputStreamReader(powerShellProcess.getInputStream()));
//		while ((lineOutput = stdout.readLine()) != null) {
//			// System.out.println(lineOutput);
//			formattedDate = lineOutput;
//		}
//		stdout.close();
//		// System.out.println("Standard Error:");
//		BufferedReader stderr = new BufferedReader(new InputStreamReader(powerShellProcess.getErrorStream()));
//		while ((lineError = stderr.readLine()) != null) {
//			System.out.println(lineError);
//		}
//		stderr.close();
		Path file = Paths.get(filePath);
		FileTime time = Files.readAttributes(file, BasicFileAttributes.class).lastAccessTime();
		Date date = new Date(time.toMillis());
//		Date date = SIMPLE_DATE_FORMAT.parse(formattedDate);
		// System.out.println(date); // Sun May 08 09:26:57 CEST 2016

		return date;
	}

//	private static String escapeSpecialChars(String filePath) {
//
//		if (filePath.contains("'")) {
//			filePath = filePath.replace("'", "`'");
//		}
//		return filePath;
//	}

	private static void initialIndexing() throws IOException, ParseException {

		File f = new File(osuPath);
		System.out.println(new Date() + " starting initial indexing!");

		songIndex = findDirectory(f);
		System.out.println(new Date() + " Indexed " + songIndex.size() + " songs!");

	}

	private static HashMap<String, Date> findDirectory(File parentDirectory) throws IOException, ParseException {
		File[] files = parentDirectory.listFiles();
		for (File file : files) {
			if (file.getName().contains(".mp3") && !file.getAbsolutePath().contains("'")) {
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
					Scanner scanner = new Scanner(new InputStreamReader(System.in));
					System.out.println("Please enter your osuPath: ");
					input = scanner.nextLine();
					if (new File(input).isDirectory()) {
						scanner.close();
						props.setProperty("osuPath", input);
					} else
						System.out.println("Not a valid dir!");
				}

			}
			if (audioShieldPath.isEmpty()) {
				String input = "";
				while (!new File(input).isDirectory()) {
					Scanner scanner = new Scanner(new InputStreamReader(System.in));
					System.out.println("Please enter your audioShieldPath: ");
					input = scanner.nextLine();
					if (new File(input).isDirectory()) {
						scanner.close();
						props.setProperty("audioShieldPath", input);
					} else
						System.out.println("Not a valid dir!");
				}

			}
			props.store(new FileOutputStream("resource/paths.properties"), null);
		}
		showMenu();
	}
}
