/*=====================================================================*/
/*    serrano/prgm/project/hop/hop/examples/lang/csv.js                */
/*    -------------------------------------------------------------    */
/*    Author      :  Manuel Serrano                                    */
/*    Creation    :  Fri Mar  9 08:41:47 2018                          */
/*    Last change :  Thu Oct 17 14:22:02 2019 (serrano)                */
/*    Copyright   :  2018-19 Manuel Serrano                            */
/*    -------------------------------------------------------------    */
/*    A csv loader                                                     */
/*=====================================================================*/



"use hopscript";

const csvloader = require( "./csv.hop" );
const fs = require( "fs" );

exports[ Symbol.compiler ] = (file, options) => {
   const val = csvloader.load( file, options );
   
   if( options && options.target ) {
      var fd = fs.openSync( options.target, "w" );
      try {
	 var buf = JSON.stringify( val );
	 fs.write( fd, buf, 0, buf.length );
	 
	 return {
	    type: "filename",
	    value: target,
	 }
      } finally {
	 fs.closeSync( options.target );
      }
   } else {
      return {
	 type: "value",
	 value: val,
      }
   }
}
