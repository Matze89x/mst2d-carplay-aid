package mst2.eu.cluster;

import org.osgi.framework.BundleActivator;
import org.osgi.framework.BundleContext;

public final class Activator implements BundleActivator {
    private StateReader reader;
    public void start(BundleContext context) {
        try {
            reader=new StateReader();
            Thread thread=new Thread(reader,"mst2-eu-rgi-hmi");
            thread.setDaemon(true);thread.start();
            System.out.println("[mst2-eu-rgi] HMI bridge started");
        } catch(Throwable error){System.out.println("[mst2-eu-rgi] HMI start failed: "+error);}
    }
    public void stop(BundleContext context){if(reader!=null){reader.stop();reader=null;}KombiMapOwner.update(false);Publisher.clear();}
}
