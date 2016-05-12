import java.io.IOException;
import java.text.ParseException;
import java.util.Scanner;

public class ListenerThread implements Runnable {

	Scanner inputReader = new Scanner(System.in);

	// Method that gets called when the object is instantiated
	public ListenerThread() {
	}

	public void run() {
		try {
			Listener.updatemap();
		} catch (IOException e) {
			e.printStackTrace();
		} catch (ParseException e) {
			e.printStackTrace();
		}
	}

}