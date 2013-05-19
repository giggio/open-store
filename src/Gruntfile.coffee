module.exports = (grunt) ->
  grunt.initConfig
    pkg: grunt.file.readJSON 'package.json'
    client:
      expand: true
      cwd: 'public'
      src: [ '**/*.coffee', '!javascripts/lib/**/*' ]
      dest: 'public'
      ext: '.js'
    server:
      expand: true
      cwd: 'app'
      src: [ '**/*.coffee' ]
      dest: 'app'
      ext: '.js'
    tests:
      expand: true
      cwd: 'test'
      src: [ '**/*.coffee' ]
      dest: 'test'
      ext: '.js'
    dev: [ 'Cakefile', 'Gruntfile.coffee' ]

    coffee:
      client:
        files: ['<%= client %>'], options: {sourceMap: true}
      server: '<%= server %>'
      tests: '<%= tests %>'

    coffeelint:
      client: '<%= client %>'
      server: '<%= server %>'
      tests: '<%= tests %>'
      dev: '<%= dev %>'
      options:
        max_line_length:
          level: 'ignore'
        coffeescript_error:
          level: 'ignore'

    watch:
      server:
        files: [ 'app/**/*.coffee', 'public/**/*.coffee', 'test/**/*.coffee' ]
        tasks: [ 'compileAndStartServer' ]
        options:
          nospawn: true
          livereload: true
      coffee:
        files: [ 'app/**/*.coffee', 'public/**/*.coffee', 'test/**/*.coffee' ]
        tasks: [ 'coffee', 'coffeelint' ]
        options:
          nospawn: true

    express:
      dev:
        options:
          script: 'server.js'

    mochacov:
      options:
        ignoreLeaks: true
      server_unit:
        src: 'test/unit/**/*.js'
        options:
          require: ['test/support/_specHelper.js']
          reporter: 'spec'
          ui: 'bdd'
      server_integration:
        src: 'test/integration/**/*.js'
        options:
          require: ['test/support/_specHelper.js']
          reporter: 'spec'
          ui: 'bdd'
          timeout: 40000
      client:
        src: 'public/javascripts/test/**/*.js'
        options:
          require: ['public/javascripts/test/support/runnerSetup.js']
          reporter: 'spec'
          ui: 'bdd'
      server_unit_coverage:
        src: 'test/unit/**/*.js'
        options:
          require: ['test/support/_specHelper.js']
          reporter: 'spec'
          ui: 'bdd'
          coverage: true

  grunt.loadNpmTasks 'grunt-coffeelint'
  grunt.loadNpmTasks 'grunt-contrib-coffee'
  grunt.loadNpmTasks 'grunt-contrib-watch'
  grunt.loadNpmTasks 'grunt-express-server'
  #grunt.loadNpmTasks 'grunt-cafe-mocha'
  grunt.loadNpmTasks 'grunt-mocha-cov'

  _ = grunt.util._
  filterFiles = (files, dir) ->
    _.chain(files)
     .filter((f) -> _(f).startsWith dir)
     .map((f)->_(f).strRight "#{dir}/")
     .value()

  changedFiles = {}
  onChange = grunt.util._.debounce ->
    files = Object.keys(changedFiles)
    serverFiles = filterFiles files, 'app'
    clientFiles = filterFiles files, 'public'
    testFiles = filterFiles files, 'test'
    grunt.config ['server', 'src'], serverFiles
    grunt.config ['client', 'src'], clientFiles
    grunt.config ['tests', 'src'], testFiles
    grunt.config ['dev'], []
    changedFiles = {}
  , 200
  grunt.event.on 'watch', (action, filepath) ->
    changedFiles[filepath] = action
    onChange()

  #TASKS:
  grunt.registerTask 'lint', [ 'coffeelint' ]
  grunt.registerTask 'server', [ 'compileAndStartServer', 'watch:server' ]
  grunt.registerTask 'compileAndStartServer', ->
    tasks = [ 'coffee', 'coffeelint' ]
    if grunt.config(['client', 'src']).length isnt 0
      tasks.push 'test:client'
      grunt.log.writeln "Running #{'client'.blue} unit tests"
    if grunt.config(['server', 'src']).length isnt 0
      tasks.push 'test:unit'
      tasks.push 'express:dev'
      grunt.log.writeln 'Compiling and starting server'
      grunt.log.writeln "Running #{'server'.blue} unit tests"
    else
      grunt.log.writeln "Compiling and #{'NOT'.red} starting server"
    grunt.task.run tasks
  grunt.registerTask 'test', ['test:unit', 'test:integration', 'test:client' ]
  grunt.registerTask 'test:fast', ['test:unit', 'test:client' ]
  grunt.registerTask 'test:unit', ['mochacov:server_unit']
  grunt.registerTask 'test:integration', ['mochacov:server_integration']
  grunt.registerTask 'test:client', ['mochacov:client']
  grunt.registerTask 'default', ['server']