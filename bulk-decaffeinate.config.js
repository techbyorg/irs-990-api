module.exports = {
  decaffeinatePath: '../../misc_git/decaffeinate/bin/decaffeinate',
  jscodeshiftScripts: ['prefer-function-declarations.js'],
  // searchDirectory: 'src',
  decaffeinateArgs: [
    '--use-js-modules', '--use-cs2', '--loose', '--disable-suggestion-comment', 
    '--use-optional-chaining'
  ]
}
