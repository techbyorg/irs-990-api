import gulp from 'gulp';
import shell from 'gulp-shell';
import coffeelint from 'gulp-coffeelint';
import { spawn } from 'child_process';

const paths = {
  serverBin: './bin/server.coffee',
  coffee: [
    './**/*.coffee',
    '!./node_modules/**/*'
  ]
};

gulp.task('default', 'dev');

gulp.task('dev', 'watch:dev');

gulp.task('watch:dev', gup.series('dev:server', () => gulp.watch(paths.coffee, ['dev:server']))
);

gulp.task('dev:server', (function() {
  let devServer = null;
  process.on('exit', () => devServer?.kill());
  return function() {
    devServer?.kill();
    devServer = spawn('coffee', [paths.serverBin], {stdio: 'inherit'});
    return devServer.on('close', function(code) {
      if (code === 8) {
        return gulp.log('Error detected, waiting for changes');
      }
    });
  };
})()
);

gulp.task('lint', () => gulp.src(paths.coffee)
  .pipe(coffeelint())
  .pipe(coffeelint.reporter()));
