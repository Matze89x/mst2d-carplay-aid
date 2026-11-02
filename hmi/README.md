# HMI-Brücke (EU) / HMI bridge (EU)

**Deutsch zuerst – English version below: [English](#english).**

Spät geladenes OSGi-Bündel, das geprüfte CarPlay-Führungsdaten über die originalen Navigations-Schnittstellen des HMI
veröffentlicht (`ASLNavBAPAPI`). Es steuert außerdem die Sichtbarkeit der Werkskarte anhand des Herzschlags des
Videostroms (Typ 111) und stellt den originalen Renderer wieder her, wenn das Video endet. Das Bündel ersetzt oder
verteilt **keine** Original-Klassen.

Übersetzen gegen das `MIBHMI.jar`, das aus der `MIBHMI.jxe` **genau des Zielgeräts** umgewandelt wurde (JDK 8, Quelltext-Stufe 1.3):

```sh
sh hmi/test.sh
sh hmi/build.sh /pfad/zu/MIBHMI.jar
```

(Unter Windows: `hmi\test.ps1` und `hmi\build.ps1 -MibHmi C:\pfad\MIBHMI.jar -JdkBin C:\jdk8\bin`.)

Der Paketbauer trägt es als spät geladenes Bündel Nr. 98 ein und hängt das erzeugte Jar an den Boot-Klassenpfad des HMI.
Es wird keine Original-Java-Klasse überschrieben.

---

<a id="english"></a>

Late-load OSGi bundle that publishes validated CarPlay guidance through the stock navigation APIs of the HMI
(`ASLNavBAPAPI`). It also arbitrates visibility of the factory map from the Type-111 video heartbeat and restores the
stock renderer when the video stops. The bundle does **not** replace or redistribute stock classes.

Compile against the `MIBHMI.jar` converted from the `MIBHMI.jxe` of **exactly the target unit** (JDK 8, source level 1.3):

```sh
sh hmi/test.sh
sh hmi/build.sh /path/to/MIBHMI.jar
```

(On Windows: `hmi\test.ps1` and `hmi\build.ps1 -MibHmi C:\path\MIBHMI.jar -JdkBin C:\jdk8\bin`.)

The stage builder registers it as late-load bundle ID 98 and adds the generated jar to the HMI boot class path. No stock
Java class is overwritten.
