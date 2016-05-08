import java.io.File;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.FilenameFilter;
import java.io.IOException;
import java.io.InputStreamReader;
import java.util.HashMap;
import java.util.Properties;
import java.util.Scanner;

public class Listener {
	public static String osuPath = "";
	public static String audioShieldPath = "";
	public static HashMap<String, Integer> songIndex = new HashMap<String, Integer>();
	public static void main(String[] args) throws IOException {


		initPaths();

		// // String command = "powershell.exe  your command";
		// // Getting the version
		// String command = "powershell.exe  \"ls\"";
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

	private static void startOrReset() {
		Scanner scanner = new Scanner(new InputStreamReader(System.in));
		System.out
				.println("type \"start\" to start listener or type \"reset\" to reset paths");
		String input = scanner.nextLine();
		if (input.contains("start")) {
			startListener();
		} else if (input.contains("reset")) {
			Properties props = new Properties();
			try {
				props.load(Listener.class
						.getResourceAsStream("paths.properties"));
				props.setProperty("osuPath", "");
				props.setProperty("audioShieldPath", "");
				props.store(new FileOutputStream("resource/paths.properties"),
						null);
				Thread.sleep(100);
				initPaths();
			} catch (IOException e) {
				e.printStackTrace();
			} catch (InterruptedException e) {
				// TODO Auto-generated catch block
				e.printStackTrace();
			}
		} else {
			System.out.println("Couldn't recognize input, try again");
			startOrReset();
		}
	}

	private static void startListener() {
		System.out.println("---------------------------------------------------------------------------");
		System.out.println("---------------Listener Started---------------------");
		initialIndexing();
		

	}

	private static void initialIndexing() {

		File f = new File(osuPath);
		songIndex =  findDirectory(f);
		System.out.println(songIndex);
	      
	}
	private static HashMap<String, Integer> findDirectory(File parentDirectory) {
        File[] files = parentDirectory.listFiles();
        for (File file : files) {
            if (file.getName().contains(".txt")) {
                songIndex.put(file.getAbsolutePath(), 1);
            }
            if(file.isDirectory()) {
               findDirectory(file);
            }
        }
        return songIndex;
    }

	private static void initPaths() throws FileNotFoundException, IOException {


		Properties props = new Properties();
		try {
			props.load(Listener.class.getResourceAsStream("paths.properties"));
		} catch (IOException e) {
			e.printStackTrace();
		}
		osuPath = props.getProperty("osuPath").toString();
		audioShieldPath = props.getProperty("audioShieldPath").toString();

		System.out.println("Path to Osu! Songs folder = " + osuPath);
		System.out.println("Path to the Osu! Audioshield Mod Folder = "
				+ audioShieldPath);
		System.out.println("---------------------------------------------------------------------------");

		if (osuPath.isEmpty() || audioShieldPath.isEmpty()) {
			System.out
					.println("Please set the paths correctly using following syntax: ");
			System.out.println("\"c:\\yourpath\\here");
			if (osuPath.isEmpty()) {
				String input = "";
				while (!new File(input).isDirectory()){
				Scanner scanner = new Scanner(new InputStreamReader(System.in));
				System.out.println("Please enter your osuPath: ");
				 input = scanner.nextLine();
				 if (new File(input).isDirectory())
					 props.setProperty("osuPath", input);
				 else
					 System.out.println("Not a valid dir!");
				}

			}
			if (audioShieldPath.isEmpty()) {
				String input = "";
				while (!new File(input).isDirectory()){
				Scanner scanner = new Scanner(new InputStreamReader(System.in));
				System.out.println("Please enter your audioShieldPath: ");
				 input = scanner.nextLine();
				 if (new File(input).isDirectory())
					 props.setProperty("audioShieldPath", input);
				 else
					 System.out.println("Not a valid dir!");
				}

			}
			props.store(new FileOutputStream("resource/paths.properties"), null);
		}
		startOrReset();
	}
}
