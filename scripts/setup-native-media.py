#!/usr/bin/env python3
from pathlib import Path
import re

root = Path("android")
manifest = root / "app/src/main/AndroidManifest.xml"
s = manifest.read_text()
permissions = [
    '    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />',
    '    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK" />',
    '    <uses-permission android:name="android.permission.WAKE_LOCK" />',
]
for permission in permissions:
    if permission not in s:
        s = s.replace("<application", permission + "\n    <application", 1)
service_decl = '        <service android:name=".QuranPlaybackService" android:exported="false" android:foregroundServiceType="mediaPlayback" />'
if "QuranPlaybackService" not in s:
    s = s.replace("</application>", service_decl + "\n    </application>", 1)
manifest.write_text(s)

gradle = root / "app/build.gradle"
g = gradle.read_text()
dependency = "    implementation 'androidx.media:media:1.7.0'"
if "androidx.media:media" not in g:
    g = re.sub(r"(dependencies\s*\{)", r"\1\n" + dependency, g, count=1)
gradle.write_text(g)

java_dir = root / "app/src/main/java/com/sajad/quranalkareem"
java_dir.mkdir(parents=True, exist_ok=True)
(java_dir / "MainActivity.java").write_text(r'''package com.sajad.quranalkareem;
import android.os.Bundle;
import com.getcapacitor.BridgeActivity;
public class MainActivity extends BridgeActivity {
  @Override public void onCreate(Bundle savedInstanceState) {
    registerPlugin(QuranMediaPlugin.class);
    super.onCreate(savedInstanceState);
  }
}
''')
(java_dir / "QuranMediaPlugin.java").write_text(r'''package com.sajad.quranalkareem;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.os.Build;
import com.getcapacitor.*;

@CapacitorPlugin(name = "QuranMedia")
public class QuranMediaPlugin extends Plugin {
  private BroadcastReceiver receiver;
  @Override public void load() {
    receiver = new BroadcastReceiver() {
      @Override public void onReceive(Context context, Intent intent) {
        JSObject data = new JSObject();
        data.put("action", intent.getStringExtra("action"));
        notifyListeners("mediaAction", data);
      }
    };
    IntentFilter filter = new IntentFilter("com.sajad.quranalkareem.MEDIA_ACTION");
    if (Build.VERSION.SDK_INT >= 33) getContext().registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED);
    else getContext().registerReceiver(receiver, filter);
  }
  @PluginMethod public void start(PluginCall call) {
    Intent i = new Intent(getContext(), QuranPlaybackService.class);
    i.setAction("START");
    i.putExtra("title", call.getString("title", "القرآن الكريم"));
    i.putExtra("artist", call.getString("artist", ""));
    if (Build.VERSION.SDK_INT >= 26) getContext().startForegroundService(i); else getContext().startService(i);
    call.resolve();
  }
  @PluginMethod public void update(PluginCall call) {
    Intent i = new Intent(getContext(), QuranPlaybackService.class);
    i.setAction("PAUSE");
    if (Build.VERSION.SDK_INT >= 26) getContext().startForegroundService(i); else getContext().startService(i);
    call.resolve();
  }
  @PluginMethod public void stop(PluginCall call) {
    Intent i = new Intent(getContext(), QuranPlaybackService.class);
    i.setAction("STOP");
    if (Build.VERSION.SDK_INT >= 26) getContext().startForegroundService(i); else getContext().startService(i);
    call.resolve();
  }
  @Override protected void handleOnDestroy() {
    if (receiver != null) { try { getContext().unregisterReceiver(receiver); } catch (Exception ignored) {} }
    super.handleOnDestroy();
  }
}
''')
(java_dir / "QuranPlaybackService.java").write_text(r'''package com.sajad.quranalkareem;
import android.app.*;
import android.content.*;
import android.media.session.MediaSession;
import android.media.session.PlaybackState;
import android.os.*;
import androidx.core.app.NotificationCompat;

public class QuranPlaybackService extends Service {
  private static final String CHANNEL = "quran-media";
  private static final int NOTIFICATION_ID = 7310;
  private MediaSession session;
  private String title = "القرآن الكريم", artist = "";
  private boolean playing = true;

  @Override public void onCreate() {
    super.onCreate();
    createChannel();
    session = new MediaSession(this, "QuranPlayback");
    session.setFlags(MediaSession.FLAG_HANDLES_MEDIA_BUTTONS | MediaSession.FLAG_HANDLES_TRANSPORT_CONTROLS);
    session.setCallback(new MediaSession.Callback() {
      @Override public void onPlay() { playing = true; updateState(); sendAction("PLAY"); updateNotification(); }
      @Override public void onPause() { playing = false; updateState(); sendAction("PAUSE"); updateNotification(); }
      @Override public void onSkipToNext() { sendAction("NEXT"); }
      @Override public void onStop() { playing = false; sendAction("STOP"); stopForeground(true); stopSelf(); }
    });
    session.setActive(true);
  }

  @Override public int onStartCommand(Intent intent, int flags, int startId) {
    if (intent == null) return START_NOT_STICKY;
    String action = intent.getAction();
    if ("START".equals(action)) {
      title = intent.getStringExtra("title") == null ? title : intent.getStringExtra("title");
      artist = intent.getStringExtra("artist") == null ? artist : intent.getStringExtra("artist");
      playing = true;
      updateState();
      startForeground(NOTIFICATION_ID, buildNotification());
    } else if ("PAUSE".equals(action)) {
      playing = false;
      updateState();
      updateNotification();
    } else if ("PLAY".equals(action)) {
      playing = true;
      updateState();
      sendAction("PLAY");
      updateNotification();
    } else if ("NEXT".equals(action)) {
      sendAction("NEXT");
    } else if ("STOP".equals(action)) {
      stopForeground(true);
      stopSelf();
    }
    return START_STICKY;
  }

  private void updateState() {
    long actions = PlaybackState.ACTION_PLAY | PlaybackState.ACTION_PAUSE |
      PlaybackState.ACTION_PLAY_PAUSE | PlaybackState.ACTION_SKIP_TO_NEXT | PlaybackState.ACTION_STOP;
    PlaybackState state = new PlaybackState.Builder()
      .setActions(actions)
      .setState(playing ? PlaybackState.STATE_PLAYING : PlaybackState.STATE_PAUSED,
        PlaybackState.PLAYBACK_POSITION_UNKNOWN, 1f)
      .build();
    session.setPlaybackState(state);
    session.setMetadata(new android.media.MediaMetadata.Builder()
      .putString(android.media.MediaMetadata.METADATA_KEY_TITLE, title)
      .putString(android.media.MediaMetadata.METADATA_KEY_ARTIST, artist).build());
  }

  private void createChannel() {
    if (Build.VERSION.SDK_INT >= 26) {
      NotificationChannel channel = new NotificationChannel(CHANNEL,
        "تشغيل القرآن الكريم", NotificationManager.IMPORTANCE_LOW);
      channel.setDescription("إشعار التحكم بتلاوة القرآن أثناء التشغيل");
      getSystemService(NotificationManager.class).createNotificationChannel(channel);
    }
  }

  private PendingIntent serviceIntent(String action, int request) {
    Intent i = new Intent(this, QuranPlaybackService.class).setAction(action);
    return PendingIntent.getService(this, request, i,
      PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
  }

  private void updateNotification() {
    getSystemService(NotificationManager.class).notify(NOTIFICATION_ID, buildNotification());
  }

  private Notification buildNotification() {
    Intent launch = getPackageManager().getLaunchIntentForPackage(getPackageName());
    PendingIntent content = launch == null ? null : PendingIntent.getActivity(this, 0, launch,
      PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
    NotificationCompat.Builder builder = new NotificationCompat.Builder(this, CHANNEL)
      .setSmallIcon(android.R.drawable.ic_media_play)
      .setContentTitle(title).setContentText(artist)
      .setContentIntent(content).setOngoing(true).setOnlyAlertOnce(true)
      .addAction(playing ? android.R.drawable.ic_media_pause : android.R.drawable.ic_media_play,
        playing ? "إيقاف مؤقت" : "تشغيل", serviceIntent(playing ? "PAUSE" : "PLAY", 1))
      .addAction(android.R.drawable.ic_media_next, "التالي", serviceIntent("NEXT", 2))
      .setStyle(new androidx.media.app.NotificationCompat.MediaStyle()
        .setMediaSession(session.getSessionToken()).setShowActionsInCompactView(0, 1));
    return builder.build();
  }

  private void sendAction(String action) {
    Intent i = new Intent("com.sajad.quranalkareem.MEDIA_ACTION")
      .setPackage(getPackageName()).putExtra("action", action);
    sendBroadcast(i);
  }

  @Override public IBinder onBind(Intent intent) { return null; }
  @Override public void onDestroy() {
    if (session != null) { session.setActive(false); session.release(); }
    super.onDestroy();
  }
}
''')
