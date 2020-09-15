var assert = require( "assert" );
var fs = require( "fs" );

var res = 0;
var content = "toto\nn'est\npas\ncontent";
var boundary = '-----------------------------71500674829540217534185294';

var fakeupload = '--' + boundary + '\r\n'
    + 'Content-Disposition: form-data; name="file"; filename="exfile"\r\n'
    + 'Content-Type: application/octet-stream\r\n\r\n'
    + content
    + '\r\n--' + boundary + '--\r\n';

/* server */ 		
service serv1( o ) {
   var x = (o && "x" in o) ? o.x : 10;
   var y = (o && "y" in o) ? o.y : 100;
   
   var x1 = Number( x ), y1 = Number( y );

   assert.ok( x1 > 0 );
   assert.ok( y1 > x1 );
   
   res++;
   
   return x1 + y1;
}

service upload( o ) {
   var file = (o && "file" in o) ? o.file : "no file";
   var stats = fs.statSync( file );
   var chars = fs.readFileSync( file );

   assert.ok( stats.isFile() && (Date.now() - stats.ctime.getTime() < 2000) );
   assert.equal( content, chars );
   res++;
   
   return 'OK' ;
}

service serv2( a, b ) {
   if( typeof a === "string" ) {
      return a.length == b.val.length + 1;
   } else {
      return a.val.length == b.length - 1;
   }
}

service serv3() {
   var o = {
      name: "foo",
      age: 34,
      nage: new Number( 43 ),
      birth: new Date(),
      re: /[ab]*c/,
      bo: new Boolean( false ),
      bo2: true,
      arr: [ { x: 10, y: 24}, { x: 14, z: 33.33 } ],
      i8: new Int8Array( [1,2,3,4,5,-6] ),
      u8: new Uint8Array( [1,2,3,4,5,-6] ),
      i16: new Int16Array( [256, 257, -258] ),
      u16: new Uint16Array( [257, -257] ),
      f32: new Float32Array( [1.0, 1.1, 1.2] ),
      f64: new Float64Array( [10001.0, 10001.1, 10001.2] ),
      dv: new DataView( new Int8Array( [1,2,3,4,5,-6] ).buffer ),
      buf: new Buffer( [-3,-2,-1,0,1,2,3,127 ] ),
      el: <div style="border: 2px solid green" id="bar">toto</div>
   };
   return o;
}
   
/* client */
var querystring = require( 'querystring' );
var http = require( 'http' );

function test() {
   var postData = querystring.stringify( {
      'x' : 1,
      'y' : 2,
   } );

   var req = http.request( {
      hostname: 'localhost',
      port: hop.port,
      path: '/hop/serv1',
      method: 'POST',
      headers: {
	 'Content-Type': 'application/x-www-form-urlencoded',
	 'Content-Length': postData.length
      }
   }, function(result) {
      result.on( 'data', function( chunk ) {
	 assert.equal( eval( chunk.toString() ), 3 );
	 console.log( "serv1...test passed" );
      } );
   } );
   req.write( postData );
   req.end();

   var req = http.request( {
      hostname: 'localhost',
      port: hop.port,
      path: '/hop/upload',
      method: 'POST',
      headers: {
	 'Content-Type': 'multipart/form-data; boundary=' + boundary,
	 'Content-Length': fakeupload.length
      }
   } );

   req.on( 'response', function( result ) {
      assert.ok( result.statusCode == 200, "statusCode" );
      result.on( 'data', function ( chunk ) {
	 var c = chunk.toString();
	 assert.ok( c == "OK" );
	 console.log( "upload...test passed" );
      });
   } );

   req.write( fakeupload );
   req.end();

   serv2( "foobar+", { x: 0, val: "foobar" } )
      .post( function( v ) {
	 assert.ok( v );
	 console.log( "serv2a...test passed" );
      } );
   serv2( { x: 0, val: "foobar" }, "foobar+" )
      .post( function( v ) {
	 assert.ok( v );
	 console.log( "serv2b...test passed" );
      } );

   serv3()
      .post( function( v ) {
	 assert.ok( v.name === "foo", "serv3a" );
	 assert.ok( v.age === 34, "serv3b" );
	 assert.ok( v.nage instanceof Number, "serv3b2" );
	 assert.ok( v.birth instanceof Date, "serv3c" );
	 assert.ok( v.re instanceof RegExp, "serv3d" );
	 assert.ok( v.bo instanceof Boolean, "serv3e" );
	 assert.ok( v.bo2, "serv3f" );
	 assert.ok( v.arr[ 0 ].x == (v.arr[ 1 ].x - 4), "serv3g" );
	 assert.ok( v.arr.length == 2, "serv3h" );
	 assert.ok( v.i8[ 5 ] == -6, "serv3i" );
	 assert.ok( v.i8[ 4 ] == 5, "serv3j" );
	 assert.ok( v.u8[ 4 ] == 5, "serv3k" );
	 assert.ok( v.i16[ 1 ] == 257, "serv3l" );
	 assert.ok( v.f32[ 0 ] < 1.1, "serv3m" );
	 assert.ok( v.f32[ 0 ] > 0.9, "serv3n" );
	 assert.ok( v.buf instanceof Buffer, "serv3o" );
	 assert.ok( v.el.id === "bar", "serv3p" );
	 console.log( "serv3...test passed" );
	 res++;
      } );
}

function checkCompletion() {
   try {
      assert.ok( res === 3, "post incomplete" );
   } finally {
      process.exit( res === 3 ? 0 : 1 );
   }
}

setTimeout( function() {
   if( hop.compilerDriver.pending > 0 ) {
      hop.compilerDriver.addEventListener( "all", function( e ) {
	 checkCompletion();
      } );
   } else {
      checkCompletion();
   }
}, 2000 );

test();


