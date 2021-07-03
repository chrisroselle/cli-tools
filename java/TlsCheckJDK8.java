import javax.net.ssl.SSLSocket;
import javax.net.ssl.SSLSocketFactory;
import java.io.*;

/**
 * source: https://confluence.atlassian.com/download/attachments/117455/SSLPoke.java
 *
 * to run:
 * javac TlsCheckJDK8
 * java TlsCheckJDK8 wwww.myurl.com 443
 */
public class TlsCheckJDK8 {
	public static void main(String[] args) throws IOException {
		if (args.length != 2) {
			System.out.println("usage: "+TlsCheckJDK8.class.getName()+" <host> <port>");
			System.exit(1);
		}
		System.setProperty("javax.net.debug", "all");
		SSLSocketFactory sslsocketfactory = (SSLSocketFactory) SSLSocketFactory.getDefault();
		SSLSocket sslsocket = (SSLSocket) sslsocketfactory.createSocket(args[0], Integer.parseInt(args[1]));

		InputStream in = sslsocket.getInputStream();
		OutputStream out = sslsocket.getOutputStream();

		// Write a test byte to get a reaction :)
		out.write(1);

		while (in.available() > 0) {
			System.out.print(in.read());
		}
		System.out.println("success");
	}
}

