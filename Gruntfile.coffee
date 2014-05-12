module.exports = ( grunt )  ->

    grunt.initConfig

        pkg : grunt.file.readJSON 'package.json'

        watch :
            files: ['src/coffeescript/*.coffee']
            tasks: 'coffee'

        coffee: 
            compile: 
                expand: true
                flatten: true
                cwd: 'src/'
                src: ['coffeescript/*.coffee']
                dest: 'src/js/'
                ext: '.js'

        concat:  
            options:
                separator: ';'
            js:
                src: [ 'src/js/vendor/underscore.js', 'src/js/plugins.js', 'src/js/main.js' ]
                dest: 'src/js/<%= pkg.name %>.js'
            css:
                src: ['src/css/normalize.min.css', 'src/css/main.css'],
                dest: 'src/css/findmehere.css'

        uglify:
            options:
                banner: '/*! <%= pkg.name %> <%= grunt.template.today("dd-mm-yyyy") %> */\n'
                flatten:true
                expand:true
            build:
                files:
                    'build/js/<%= pkg.name %>.min.js': ['<%= concat.js.dest %>']
        cssmin:
            minify:
                expand:true
                cwd: 'src/css'
                src: 'findmehere.css'
                dest: 'build/css/'
                ext: '.min.css'
        copy:
            main:
                expand: true
                cwd: 'src'
                dest: 'build'
                src: [ 'index.html', 'graphics/**/*', 'favicon.ico', 'js/vendor/html5shiv.js', 'snapshot/**/*', '.htaccess' ]
        clean:
            cwd: ''
            options:
                force: true
            build:
                src : [ 'build' ]
        processhtml :
            build:
                options:
                    templateSettings :
                        opener: '{{'
                        closer: '}}'
                    process: true
                files: 'build/index.html' : [ 'build/index.html' ]
        ftp_push : 
            findmehere:
                options:
                    authKey: 'production'
                    host: '12.112.112.11'
                    dest: '/httpdocs/'
                    port: 21
                files: [ 
                    expand: true
                    cwd: 'build'
                    src: ['**/*']
                ]
        

    # These plugins provide necessary tasks.
    grunt.loadNpmTasks 'grunt-contrib-coffee'
    grunt.loadNpmTasks 'grunt-contrib-copy'
    grunt.loadNpmTasks 'grunt-contrib-clean'
    grunt.loadNpmTasks 'grunt-contrib-watch'
    grunt.loadNpmTasks 'grunt-contrib-clean'
    grunt.loadNpmTasks 'grunt-contrib-concat'
    grunt.loadNpmTasks 'grunt-contrib-uglify'
    grunt.loadNpmTasks 'grunt-contrib-cssmin'
    grunt.loadNpmTasks 'grunt-processhtml'
    grunt.loadNpmTasks 'grunt-ftp-push'
    
    # Default task.
    grunt.registerTask 'default', [ 'watch' ]
    grunt.registerTask 'build', [ 'wipe', 'coffee', 'concat', 'uglify', 'cssmin', 'copy', 'processhtml' ]
    grunt.registerTask 'deploy', [ 'build', 'ftp_push' ]
    grunt.registerTask 'wipe', [ 'clean:build' ]
    
    return