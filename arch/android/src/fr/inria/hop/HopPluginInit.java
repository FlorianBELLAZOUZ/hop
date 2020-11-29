/*=====================================================================*/
/*    .../hop/hop/arch/android/src/fr/inria/hop/HopPluginInit.java     */
/*    -------------------------------------------------------------    */
/*    Author      :  Manuel Serrano                                    */
/*    Creation    :  Tue Oct 19 09:44:16 2010                          */
/*    Last change :  Sun Nov 29 08:17:10 2020 (serrano)                */
/*    Copyright   :  2010-20 Manuel Serrano                            */
/*    -------------------------------------------------------------    */
/*    The initial plugin that allows plugin installation               */
/*=====================================================================*/

/*---------------------------------------------------------------------*/
/*    The package                                                      */
/*---------------------------------------------------------------------*/
package fr.inria.hop;

import android.app.*;
import android.os.*;
import android.util.Log;

import dalvik.system.*;

import java.lang.*;
import java.io.*;
import java.lang.reflect.*;

/*---------------------------------------------------------------------*/
/*    The class                                                        */
/*---------------------------------------------------------------------*/
public class HopPluginInit extends HopPlugin {
   final Class[] classes = new Class[ 3 ];
   
   HopPluginInit( HopDroid h, String n ) throws ClassNotFoundException {
      super( h, n );

      try {
	 classes[ 0 ] = Class.forName( "fr.inria.hop.HopDroid" );
	 classes[ 1 ] = Class.forName( "java.lang.String" );
      } catch( ClassNotFoundException e ) {
	 Log.e( "HopPluginInit", "server error "
		+ e.toString() + " class not found." );
	 throw e;
      }
   }
   
   // static variables
   void server( InputStream ip, OutputStream op ) throws IOException {
      String name = HopDroid.read_string( ip );

      if( name.equals( "reboot" ) ) {
	 Log.v( "HopPluginInit", "reboot..." );
	 hopdroid.service.hop.restart();
      } else {
	 int id = HopDroid.getPlugin( name );

	 Log.d( "HopPluginInit", "name=" + name + " id=" + id );

	 if( id < 0 ) {
	    // we don't have loaded that plugin yet
	    int i = name.lastIndexOf( '/' );
	    int j = name.lastIndexOf( '.' );
	    String cname = "fr.inria.hop."
	       + name.substring( (i < 0 ? 0 : i + 1), (j <= i ? name.length() : j) );
	    String tmp =
	       Environment.getExternalStorageDirectory().getAbsolutePath();
	    
	    try {
	       DexClassLoader dexLoader = new DexClassLoader(
		  name, tmp, null, HopDroid.class.getClassLoader() );
	       Log.v( "HopPluginInit", "Loading class \"" + cname + "\""
		      + " from JAR file \"" + name + "\"" );
	       Class<?> clazz = dexLoader.loadClass( cname );
	    
	       Constructor constr = clazz.getConstructor( classes );
	       Object[] args = { handroid, name };
	       HopPlugin p = (HopPlugin)constr.newInstance( args );

	       id = HopDroid.registerPlugin( p );
	       Log.v( "HopPluginInit", "plugin " + p.name + " registered..." );
	    } catch( ClassNotFoundException e ) {
	       Log.e( "HopPlugInit", "Class Not Found: " + cname );
	       op.write( "-2 ".getBytes() );
	       return;
	    } catch( NoSuchMethodException e ) {
	       Log.e( "HopPlugInit", "No such method: " + cname );
	       op.write( "-3 ".getBytes() );
	       return;
	    } catch( SecurityException e ) {
	       Log.e( "HopPlugInit", "Security exception: " + cname );
	       op.write( "-4 ".getBytes() );
	       return;
	    } catch( InstantiationException e ) {
	       Log.e( "HopPlugInit", "Instantiate exception: " + cname );
	       op.write( "-5 ".getBytes() );
	       return;
	    } catch( IllegalAccessException e ) {
	       Log.e( "HopPlugInit", "Illegal access: " + cname );
	       op.write( "-6 ".getBytes() );
	       return;
	    } catch( IllegalArgumentException e ) {
	       Log.e( "HopPlugInit", "Illegal argument: " + cname );
	       op.write( "-7 ".getBytes() );
	       return;
	    } catch( InvocationTargetException e ) {
	       Log.e( "HopPlugInit", "Invocation target exception: " + cname );
	       op.write( "-8 ".getBytes() );
	       return;
	    }
	 }

	 op.write( Integer.toString( id ).getBytes() );
	 op.write( " ".getBytes() );
      }
   }
}
