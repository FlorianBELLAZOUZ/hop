/*=====================================================================*/
/*    serrano/prgm/project/hop/3.2.x/test/hopjs/noserv/cache.js        */
/*    -------------------------------------------------------------    */
/*    Author      :  Manuel Serrano                                    */
/*    Creation    :  Sat Sep 27 10:27:29 2014                          */
/*    Last change :  Wed May  8 09:34:36 2019 (serrano)                */
/*    Copyright   :  2014-19 Manuel Serrano                            */
/*    -------------------------------------------------------------    */
/*    Hiddent class and caches testing.                                */
/*=====================================================================*/
"use strict";

const assert = require( "assert" );

/*---------------------------------------------------------------------*/
/*    method proto caching                                             */
/*---------------------------------------------------------------------*/
let p = {
   f: function( x ) { return this.a }
}

function OBJ() {
   this.a = 23;
   this.b = 32;
}

function caller( o ) {
   // prevent inlining with a dummy code
   if( "dummy" in o ) {
      for( let i = 0; i < o.dummy; i++ ) {
	 var t = new OBJ();
	 if( i == 2 ) { a.length = 3; }
	 if( i == 3 ) {
            if( i in a ) { console.log( "a=", a ); return -2; }
            if( Object.getOwnPropertyDescriptor( a, "" + i ) ) return -3;
            if( a.hasOwnProperty( "" + i ) ) return -4;
            if( a[ i ] !== undefined ) { console.log( a[ i ] ); return -5; }
            return 0;
	 };
      }
   }
   
   return o.f( 1 );
}

function test( p ) {
   OBJ.prototype = p;
   let o = new OBJ();

   let r = 0;
   r += caller( o );
   p.f = function( y ) { return this.b };
   r += caller( o )

   return r;
}

console.log( "proto changed" );
assert.ok( test( p ) === 23 + 32, "proto changed" );

let p2 = new Object();
p2.f = function( x ) { return this.a }
p2.f = function( x ) { return this.a }

console.log( "proto changed (fun mutation)" );
assert.ok( test( p2 ) === 23 + 32, "proto changed (fun mutation)" );

let p3 = new Object();
p3.f = 23;
p3.f = function( x ) { return this.a }

console.log( "proto changed (non-fun mutation)" );
assert.ok( test( p3 ) === 23 + 32, "proto changed (non-fun mutation)" );

/*---------------------------------------------------------------------*/
/*    method direct caching                                            */
/*---------------------------------------------------------------------*/
function OBJ2( f ) {
   this.f = f;
   this.a = 23;
   this.b = 32;
}

function test2() {
   let o = new OBJ2( function( x ) { return this.a } );
   let r = 0;
   
   r += caller( o );
   o.f = function( y ) { return this.b };
   r += caller( o )

   return r;
}

console.log( "function changed" );
assert.ok( test2() === 23 + 32, "proto changed" );

/*---------------------------------------------------------------------*/
/*    method direct caching                                            */
/*---------------------------------------------------------------------*/
function test3() {
   let o = new OBJ2( 3 );
   let r = 0;

   o.f = function( x ) { return this.a };
   
   r += caller( o );
   o.f = function( y ) { return this.b };
   r += caller( o )

   return r;
}

console.log( "value first" );
assert.ok( test3() === 23 + 32, "value first" );

/*---------------------------------------------------------------------*/
/*    prototype override                                               */
/*---------------------------------------------------------------------*/
function test4() {
   OBJ.prototype = p;
   p.f = function() { return this.a; };
   let o = new OBJ( 3 );
   let r = 0;

   r += caller( o );
   o.f = function( y ) { return this.b };
   r += caller( o )

   return r;
}

console.log( "prototype override" );
assert.ok( test4() === 23 + 32, "prototype override" );

/*---------------------------------------------------------------------*/
/*    method caching                                                   */
/*---------------------------------------------------------------------*/
function method() {
   function ctor( firstChecker ) {
      this.a = 10;
      this.firstChecker = firstChecker;
   }

   function f1( a, b, c, d ) {
      return "f1";
   }

   function f2( a, b, c, d ) {
      return "f2";
   }

   function call( o, a, b, c, d ) {
      return o.firstChecker( a, b, c, d );
   }

   function test() {
      var o1 = new ctor( f1 );
      var o2 = new ctor( f2 );

      for( let i = 0; i < 20000; i++ ) {
      	 call( o1, 100, 30, 0, 0 );
      	 call( o2, 100, 30, 0, 0 );
      }

      return call( o1, 100, 30, 0, 0 ) + call( o2, 100, 30, 0, 0 ) === "f1f2";
   }
   
   return test();
}

console.log( "method caching" );
assert.ok( method(), "method caching" );
