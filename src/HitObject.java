import java.util.Scanner;

public class HitObject {

	Scanner inputReader = new Scanner(System.in);
	private String time;
	private String type;
	private String content;

	// Method that gets called when the object is instantiated
	public HitObject(String time, String type, String content) {
		this.setTime(time);
		this.setType(type);
		this.setContent(content);
	}

	public String getTime() {
		return time;
	}

	public void setTime(String time) {
		this.time = time;
	}

	public String getType() {
		return type;
	}

	public void setType(String type) {
		this.type = type;
	}

	public String getContent() {
		return content;
	}

	public void setContent(String content) {
		this.content = content;
	}

}