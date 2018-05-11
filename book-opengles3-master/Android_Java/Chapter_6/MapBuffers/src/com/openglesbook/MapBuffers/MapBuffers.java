package com.openglesbook.MapBuffers;

import android.app.Activity;
import android.app.ActivityManager;
import android.content.Context;
import android.content.pm.ConfigurationInfo;
import android.opengl.GLSurfaceView;
import android.os.Bundle;
import android.util.Log;

/**
 * Activity class for example program that detects OpenGL ES 3.0.
 **/
public class MapBuffers extends Activity
{

   private final int CONTEXT_CLIENT_VERSION = 3;

   @Override
   protected void onCreate ( Bundle savedInstanceState )
   {
      super.onCreate ( savedInstanceState );
      mGLSurfaceView = new GLSurfaceView ( this );

      if ( detectOpenGLES30() )
      {
         // Tell the surface view we want to create an OpenGL ES 3.0-compatible
         // context, and set an OpenGL ES 3.0-compatible renderer.
         mGLSurfaceView.setEGLContextClientVersion ( CONTEXT_CLIENT_VERSION );
         mGLSurfaceView.setRenderer ( new MapBuffersRenderer ( this ) );
      }
      else
      {
         Log.e ( "SimpleTexture2D", "OpenGL ES 3.0 not supported on device.  Exiting..." );
         finish();

      }

      setContentView ( mGLSurfaceView );
   }

   private boolean detectOpenGLES30()
   {
      ActivityManager am =
         ( ActivityManager ) getSystemService ( Context.ACTIVITY_SERVICE );
      ConfigurationInfo info = am.getDeviceConfigurationInfo();
      return ( info.reqGlEsVersion >= 0x30000 );
   }

   @Override
   protected void onResume()
   {
      // Ideally a game should implement onResume() and onPause()
      // to take appropriate action when the activity looses focus
      super.onResume();
      mGLSurfaceView.onResume();
   }

   @Override
   protected void onPause()
   {
      // Ideally a game should implement onResume() and onPause()
      // to take appropriate action when the activity looses focus
      super.onPause();
      mGLSurfaceView.onPause();
   }

   private GLSurfaceView mGLSurfaceView;
}
