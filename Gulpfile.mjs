// TODO: This file was created by bulk-decaffeinate.
// Sanity-check the conversion and remove this comment.
import gulp from 'gulp'
import { spawn } from 'child_process'

const paths = {
  serverBin: './bin/server.js',
  js: [
    './**/*.js',
    '!./node_modules/**/*'
  ]
}

gulp.task('default', 'dev')

gulp.task('dev', 'watch:dev')

gulp.task('watch:dev', gulp.series('dev:server', () => gulp.watch(paths.js, ['dev:server']))
)

let devServer = null
gulp.task('dev:server', function () {
  process.on('exit', () => devServer?.kill())
  devServer && devServer.kill()
  devServer = spawn('js', [paths.serverBin], { stdio: 'inherit' })
  return devServer.on('close', function (code) {
    if (code === 8) {
      return gulp.log('Error detected, waiting for changes')
    }
  })
})
