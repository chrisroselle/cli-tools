import java.io.IOException;
import java.net.URI;
import java.net.URISyntaxException;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;

public class TlsCheckJDK11 {
	/*
	 to run:
	 javac TlsCheckJDK11
	 java TlsCheckJDK11 https://www.myurl.com
	 */
    public static void main(String[] args) throws URISyntaxException, IOException, InterruptedException {
    	if (args.length == 0) {
    		System.out.println("usage: java TlsCheckJDK11 <url>");
    		System.exit(1);
		}
	    System.setProperty("javax.net.debug", "all");
	    HttpRequest req = HttpRequest.newBuilder(new URI(args[0])).GET().build();
	    HttpResponse<String> res = HttpClient.newBuilder().build().send(req, HttpResponse.BodyHandlers.ofString());
	    System.out.println("success");
    }
}
