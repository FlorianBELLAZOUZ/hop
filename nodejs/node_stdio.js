/*=====================================================================*/
/*    serrano/prgm/project/hop/3.0.x/nodejs/node_stdio.js              */
/*    -------------------------------------------------------------    */
/*    Author      :  Manuel Serrano                                    */
/*    Creation    :  Thu Oct  9 18:26:51 2014                          */
/*    Last change :  Tue Sep 22 07:58:38 2015 (serrano)                */
/*    Copyright   :  2014-22 Manuel Serrano                            */
/*    -------------------------------------------------------------    */
/*    Stdio initialization                                             */
/*=====================================================================*/
// This is an excerpt an node.js that initializes stdio
var startup = {};
var NativeModule = {};
NativeModule.require = require;

function createWritableStdioStream(fd) {
   var stream;
   var tty_wrap = process.binding('tty_wrap');
   // Note stream._type is used for test-module-load-list.js

   switch (tty_wrap.guessHandleType(fd)) {
   case 'TTY':
      var tty = NativeModule.require('tty');
      stream = new tty.WriteStream(fd);
      stream._type = 'tty';

      // Hack to have stream not keep the event loop alive.
      // See https://github.com/joyent/node/issues/1726
      if (stream._handle && stream._handle.unref) {
         stream._handle.unref();
      }
      break;

   case 'FILE':
      var fs = NativeModule.require('fs');
      stream = new fs.SyncWriteStream(fd, { autoClose: false });
      stream._type = 'fs';
      break;

   case 'PIPE':
   case 'TCP':
      var net = NativeModule.require('net');
      stream = new net.Socket({
         fd: fd,
         readable: false,
         writable: true
      });

      // FIXME Should probably have an option in net.Socket to create a
      // stream from an existing fd which is writable only. But for now
      // we'll just add this hack and set the `readable` member to false.
      // Test: ./node test/fixtures/echo.js < /etc/passwd
      stream.readable = false;
      stream.read = null;
      stream._type = 'pipe';

      // FIXME Hack to have stream not keep the event loop alive.
      // See https://github.com/joyent/node/issues/1726
      if (stream._handle && stream._handle.unref) {
         stream._handle.unref();
      }
      break;

   default:
      // Probably an error on in uv_guess_handle()
      throw new Error('Implement me. Unknown stream file type!');
   }

   // For supporting legacy API we put the FD here.
   stream.fd = fd;

   stream._isStdio = true;

   return stream;
}

startup.processStdio = function( process ) {
   var stdin, stdout, stderr;
   process.__defineGetter__('stdout', function() {
      if (stdout) return stdout;
      stdout = createWritableStdioStream(1);
      stdout.destroy = stdout.destroySoon = function(er) {
         er = er || new Error('process.stdout cannot be closed.');
         stdout.emit('error', er);
      };
      if (stdout.isTTY) {
         process.on('SIGWINCH', function() {
            stdout._refreshSize();
         });
      }
      return stdout;
   });

   process.__defineGetter__('stderr', function() {
      if (stderr) return stderr;
      stderr = createWritableStdioStream(2);
      stderr.destroy = stderr.destroySoon = function(er) {
         er = er || new Error('process.stderr cannot be closed.');
         stderr.emit('error', er);
      };
      return stderr;
   });

   process.__defineGetter__('stdin', function() {
      if (stdin) return stdin;

      var tty_wrap = process.binding('tty_wrap');
      var fd = 0;

      switch (tty_wrap.guessHandleType(fd)) {
      case 'TTY':
         var tty = NativeModule.require('tty');
         stdin = new tty.ReadStream(fd, {
            highWaterMark: 0,
            readable: true,
            writable: false
         });
         break;

      case 'FILE':
         var fs = NativeModule.require('fs');
         stdin = new fs.ReadStream(null, { fd: fd, autoClose: false });
         break;

      case 'PIPE':
      case 'TCP':
         var net = NativeModule.require('net');
         stdin = new net.Socket({
            fd: fd,
            readable: true,
            writable: false
         });
         break;

      default:
         // Probably an error on in uv_guess_handle()
         throw new Error('Implement me. Unknown stdin file type!');
      }

      // For supporting legacy API we put the FD here.
      stdin.fd = fd;

      // stdin starts out life in a paused state, but node doesn't
      // know yet.  Explicitly to readStop() it to put it in the
      // not-reading state.
      if (stdin._handle && stdin._handle.readStop) {
         stdin._handle.reading = false;
         stdin._readableState.reading = false;
         stdin._handle.readStop();
      }

      // if the user calls stdin.pause(), then we need to stop reading
      // immediately, so that the process can close down.
      stdin.on('pause', function() {
         if (!stdin._handle)
            return;
         stdin._readableState.reading = false;
         stdin._handle.reading = false;
         stdin._handle.readStop();
      });

      return stdin;
   });

   process.openStdin = function() {
      process.stdin.resume();
      return process.stdin;
   };
}

/*---------------------------------------------------------------------*/
/*    initNodeStdio ...                                                */
/*---------------------------------------------------------------------*/
function initNodeStdio( process ) {
   startup.processStdio( process );
/*    process.stdout.__proto__ = events.EventEmitter.prototype;        */
/*    process.stderr.__proto__ = events.EventEmitter.prototype;        */
/*    process.stdin.__proto__ = events.EventEmitter.prototype;         */
}
   
exports.initNodeStdio = initNodeStdio;
