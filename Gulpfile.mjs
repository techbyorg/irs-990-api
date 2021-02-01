import gulp from 'gulp'
import { spawn } from 'child_process'

const paths = {
  serverBin: './bin/server.js',
  js: [
    './**/*.js',
    '!./node_modules/**/*'
  ]
}

let devServer = null
gulp.task('dev:server', function (done) {
  process.on('exit', () => devServer?.kill())
  devServer && devServer.kill()
  devServer = spawn('node', [paths.serverBin], { stdio: 'inherit' })
  done()
  return devServer.on('close', function (code) {
    if (code === 8) {
      return gulp.log('Error detected, waiting for changes')
    }
  })
})

gulp.task('dev', gulp.parallel('dev:server', () => gulp.watch(paths.js, gulp.series('dev:server'))))
