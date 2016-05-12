import java.util.Scanner;

public class HitObject {

	Scanner inputReader = new Scanner(System.in);
	private String time;
	private String type;
	private String content;
	private String posX;
	private String posY;

	// Method that gets called when the object is instantiated
	public HitObject(String time, String type, String content) {
		this.setTime(time);
		this.setType(type);
		this.setContent(content);
		this.setPosX(content.substring(0,content.indexOf(",")));
		this.setPosY(content.substring(Listener.nthIndexOf(content, ",", 1)+1,Listener.nthIndexOf(content, ",", 2)));

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


	public String getPosY() {
		return posY;
	}

	public void setPosY(String posY) {
		this.posY = posY;
	}

	public String getPosX() {
		return posX;
	}

	public void setPosX(String posX) {
		this.posX = posX;
	}

}