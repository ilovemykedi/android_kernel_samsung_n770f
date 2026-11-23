package com.n770f.dpf;

import android.os.Binder;
import android.os.IBinder;
import android.os.Looper;
import android.os.Parcel;
import android.util.Log;

import java.util.Arrays;
import java.util.HashMap;

/**
 * Minimal stand-in for OnePlus' vendor.oplus.hardware.displaypanelfeature
 * AIDL HAL, which the Samsung vendor does not have. ColorOS SystemUI only
 * enables the AOD <-> lock screen smooth transition if feature 217 reports
 * bit 1 (0x2). Other features are stored and echoed back.
 *
 * Wire format (from SystemUI's IDisplayPanelFeature$Stub$Proxy):
 *   1 getDisplayPanelFeatureValue(int code, out int[] v) -> int
 *   2 setDisplayPanelFeatureValue(int code, in int[] v)  -> int
 *   3 getDisplayPanelInfo(int code, out String[] v)      -> int
 *   0xfffffe getInterfaceHash, 0xffffff getInterfaceVersion
 */
public final class Main extends Binder {
    static final String TAG = "n770f-dpf";
    static final String DESCRIPTOR = "vendor.oplus.hardware.displaypanelfeature.IDisplayPanelFeature";
    static final String NAME = DESCRIPTOR + "/default";

    /** feature 217: bit0 gotoDozeWithOff, bit1 smooth transition, bit2/3 panoramic AOD */
    static final int FEATURE_AOD = 217;
    static final int INTERFACE_TRANSACTION = 0x5f4e5446;   // '_NTF'

    private final HashMap<Integer, int[]> values = new HashMap<>();

    Main(int aodFeature) {
        values.put(FEATURE_AOD, new int[] { aodFeature });
    }

    @Override
    protected boolean onTransact(int code, Parcel data, Parcel reply, int flags) {
        if (code == INTERFACE_TRANSACTION) {
            reply.writeString(DESCRIPTOR);
            return true;
        }
        data.enforceInterface(DESCRIPTOR);
        switch (code) {
        case 1: {
            int feature = data.readInt();
            int len = data.readInt();
            int[] out = new int[len < 0 ? 0 : len];
            int[] v = values.get(feature);
            if (v != null)
                System.arraycopy(v, 0, out, 0, Math.min(v.length, out.length));
            Log.i(TAG, "get " + feature + " len " + len + " -> " + Arrays.toString(out));
            reply.writeNoException();
            reply.writeInt(v != null ? 0 : -1);
            reply.writeIntArray(out);
            return true;
        }
        case 2: {
            int feature = data.readInt();
            int[] v = data.createIntArray();
            Log.i(TAG, "set " + feature + " " + Arrays.toString(v));
            /* SystemUI writes transition states to 217; keep its capability bits */
            if (feature != FEATURE_AOD && v != null)
                values.put(feature, v);
            reply.writeNoException();
            reply.writeInt(0);
            return true;
        }
        case 3: {
            int feature = data.readInt();
            int len = data.readInt();
            Log.i(TAG, "info " + feature + " len " + len);
            reply.writeNoException();
            reply.writeInt(-1);
            reply.writeStringArray(new String[len < 0 ? 0 : len]);
            return true;
        }
        case 0xfffffe:
            reply.writeNoException();
            reply.writeString("notfrozen");
            return true;
        case 0xffffff:
            reply.writeNoException();
            reply.writeInt(1);
            return true;
        default:
            Log.w(TAG, "unknown transaction " + code);
            return false;
        }
    }

    public static void main(String[] args) throws Exception {
        Looper.prepareMainLooper();
        /*
         * 217 bits: 0x2 smooth transition; 0x1 set = enter AOD directly in
         * doze (clear makes SystemUI blank the display first, "gotoDozeWithOff").
         */
        int aod = args.length > 0 ? Integer.decode(args[0]) : 0x3;
        Main svc = new Main(aod);
        Class<?> sm = Class.forName("android.os.ServiceManager");
        sm.getMethod("addService", String.class, IBinder.class).invoke(null, NAME, svc);
        Log.i(TAG, "registered " + NAME + ", feature 217 = " + aod);
        Looper.loop();
    }
}
