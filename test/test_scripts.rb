#!/usr/bin/ruby -w

#
# Test use of scripts in config.xml files to generate files, control the
# creation of links and directories, and control the deletion of files
#

require File.join(File.dirname(__FILE__), 'etchtest')

class EtchScriptTests < Test::Unit::TestCase
  include EtchTests

  def setup
    # Generate a file to use as our etch target/destination
    @targetfile = released_tempfile
    #puts "Using #{@targetfile} as target file"

    # Generate a directory for our test repository
    @repodir = initialize_repository
    @server = get_server(@repodir)

    # Create a directory to use as a working directory for the client
    @testroot = tempdir
    #puts "Using #{@testroot} as client working directory"
  end

  def test_scripts
    #
    # Put some content in the original file so that we can use it later
    #
    origcontents = "This is the original text\n"
    File.open(@targetfile, 'w') do |file|
      file.write(origcontents)
    end

    #
    # Start with a test of a script with a syntax error
    #

    FileUtils.mkdir_p("#{@repodir}/source/#{@targetfile}")
    File.open("#{@repodir}/source/#{@targetfile}/config.xml", 'w') do |file|
      file.puts <<-EOF
        <config>
          <file>
            <source>
              <script>source.script</script>
            </source>
          </file>
        </config>
      EOF
    end

    File.open("#{@repodir}/source/#{@targetfile}/source.script", 'w') do |file|
      file.write('syntax error')
    end

    # Gather some stats about the file before we run etch
    before_size = File.stat(@targetfile).size
    before_ctime = File.stat(@targetfile).ctime

    # Run etch
    #puts "Running script with syntax error test"
    run_etch(@server, @testroot, :errors_expected => true)

    # Verify that etch didn't do anything to the file
    assert_equal(before_size, File.stat(@targetfile).size, 'script with syntax error size comparison')
    assert_equal(before_ctime, File.stat(@targetfile).ctime, 'script with syntax error ctime comparison')

    #
    # Run a test where the script doesn't output anything
    #

    FileUtils.mkdir_p("#{@repodir}/source/#{@targetfile}")
    File.open("#{@repodir}/source/#{@targetfile}/config.xml", 'w') do |file|
      file.puts <<-EOF
        <config>
          <file>
            <source>
              <script>source.script</script>
            </source>
          </file>
        </config>
      EOF
    end

    File.open("#{@repodir}/source/#{@targetfile}/source.script", 'w') do |file|
      file.puts('true')
    end

    # Gather some stats about the file before we run etch
    before_size = File.stat(@targetfile).size
    before_ctime = File.stat(@targetfile).ctime

    # Run etch
    #puts "Running script with no output"
    run_etch(@server, @testroot)

    # Verify that etch didn't do anything to the file
    assert_equal(before_size, File.stat(@targetfile).size, 'script with no output size comparison')
    assert_equal(before_ctime, File.stat(@targetfile).ctime, 'script with no output ctime comparison')

    #
    # Run a test using a script to generate the contents of a file
    #

    FileUtils.mkdir_p("#{@repodir}/source/#{@targetfile}")
    File.open("#{@repodir}/source/#{@targetfile}/config.xml", 'w') do |file|
      file.puts <<-EOF
        <config>
          <file>
            <source>
              <script>source.script</script>
            </source>
          </file>
        </config>
      EOF
    end

    sourcecontents = "This is a test\n"
    File.open("#{@repodir}/source/#{@targetfile}/source.script", 'w') do |file|
      file.puts("@contents << '#{sourcecontents}'")
    end

    # Run etch
    #puts "Running file script test"
    run_etch(@server, @testroot)

    # Verify that the file was created properly
    correctcontents = ''
    IO.foreach(File.join(@repodir, 'warning.txt')) do |line|
      correctcontents << '# ' + line
    end
    correctcontents << "\n"
    correctcontents << sourcecontents

    assert_equal(correctcontents, get_file_contents(@targetfile), 'file script')

    #
    # Run a test where the script reads the contents from another file
    #

    FileUtils.mkdir_p("#{@repodir}/source/#{@targetfile}")
    File.open("#{@repodir}/source/#{@targetfile}/config.xml", 'w') do |file|
      file.puts <<-EOF
        <config>
          <file>
            <source>
              <script>source.script</script>
            </source>
          </file>
        </config>
      EOF
    end

    # Vary the contents a bit from the previous test so that we're sure
    # the file is updated.
    sourcecontents = "This is a test using another file\n"
    File.open("#{@repodir}/source/#{@targetfile}/source", 'w') do |file|
      file.write(sourcecontents)
    end
    File.open("#{@repodir}/source/#{@targetfile}/source.script", 'w') do |file|
      file.puts("@contents << IO.read('source')")
    end

    # Run etch
    #puts "Running file source script test"
    run_etch(@server, @testroot)

    # Verify that the file was created properly
    correctcontents = ''
    IO.foreach(File.join(@repodir, 'warning.txt')) do |line|
      correctcontents << '# ' + line
    end
    correctcontents << "\n"
    correctcontents << sourcecontents

    assert_equal(correctcontents, get_file_contents(@targetfile), 'file source script')

    #
    # Run a test where the script appends to the original file
    #

    FileUtils.mkdir_p("#{@repodir}/source/#{@targetfile}")
    File.open("#{@repodir}/source/#{@targetfile}/config.xml", 'w') do |file|
      file.puts <<-EOF
        <config>
          <file>
            <source>
              <script>source.script</script>
            </source>
          </file>
        </config>
      EOF
    end

    sourcecontents = "This is a test\n"
    File.open("#{@repodir}/source/#{@targetfile}/source", 'w') do |file|
      file.write(sourcecontents)
    end
    File.open("#{@repodir}/source/#{@targetfile}/source.script", 'w') do |file|
      file.puts("@contents << IO.read(@original_file)")
      file.puts("@contents << IO.read('source')")
    end

    # Run etch
    #puts "Running file source script test"
    run_etch(@server, @testroot)

    # Verify that the file was created properly
    correctcontents = ''
    IO.foreach(File.join(@repodir, 'warning.txt')) do |line|
      correctcontents << '# ' + line
    end
    correctcontents << "\n"
    correctcontents << origcontents
    correctcontents << sourcecontents

    assert_equal(correctcontents, get_file_contents(@targetfile), 'original append script')

    #
    # Run a test of using a script to generate a link
    #

    FileUtils.mkdir_p("#{@repodir}/source/#{@targetfile}")
    File.open("#{@repodir}/source/#{@targetfile}/config.xml", 'w') do |file|
      file.puts <<-EOF
        <config>
          <link>
            <script>link.script</script>
          </link>
        </config>
      EOF
    end

    # Generate a file to use as our link target
    @destfile = released_tempfile
    File.open("#{@repodir}/source/#{@targetfile}/link.script", 'w') do |file|
      file.puts("@contents << '#{@destfile}'")
    end

    # Run etch
    #puts "Running link script test"
    run_etch(@server, @testroot)

    # Verify that the link was created properly
    assert_equal(@destfile, File.readlink(@targetfile), 'link script')

    #
    # Run a test where the script doesn't output anything in link
    # context
    #

    FileUtils.mkdir_p("#{@repodir}/source/#{@targetfile}")
    File.open("#{@repodir}/source/#{@targetfile}/config.xml", 'w') do |file|
      file.puts <<-EOF
        <config>
          <link>
            <script>link.script</script>
          </link>
        </config>
      EOF
    end

    File.open("#{@repodir}/source/#{@targetfile}/link.script", 'w') do |file|
      file.puts('true')
    end

    # Gather some stats about the file before we run etch
    before_readlink = File.readlink(@targetfile)
    before_ctime = File.stat(@targetfile).ctime

    # Run etch
    #puts "Running link script with no output"
    run_etch(@server, @testroot)

    # Verify that etch didn't do anything to the file
    assert_equal(before_readlink, File.readlink(@targetfile), 'link script with no output readlink comparison')
    assert_equal(before_ctime, File.stat(@targetfile).ctime, 'link script with no output ctime comparison')

    #
    # Run a test of using a script to generate a directory
    #

    FileUtils.mkdir_p("#{@repodir}/source/#{@targetfile}")
    File.open("#{@repodir}/source/#{@targetfile}/config.xml", 'w') do |file|
      file.puts <<-EOF
        <config>
          <directory>
            <script>directory.script</script>
          </directory>
        </config>
      EOF
    end

    File.open("#{@repodir}/source/#{@targetfile}/directory.script", 'w') do |file|
      file.puts("@contents << 'true'")
    end

    # Run etch
    #puts "Running directory script test"
    run_etch(@server, @testroot)

    # Verify that the directory was created
    assert(File.directory?(@targetfile), 'directory script')

    #
    # Run a test where the script doesn't output anything in directory
    # context
    #

    FileUtils.mkdir_p("#{@repodir}/source/#{@targetfile}")
    File.open("#{@repodir}/source/#{@targetfile}/config.xml", 'w') do |file|
      file.puts <<-EOF
        <config>
          <directory>
            <script>directory.script</script>
          </directory>
        </config>
      EOF
    end

    File.open("#{@repodir}/source/#{@targetfile}/directory.script", 'w') do |file|
      file.puts('true')
    end

    # Change the permissions so etch will be sure to do something if it
    # does decide to proceed
    File.chmod(0666, @targetfile)

    # Gather some stats about the file before we run etch
    before_size = File.stat(@targetfile).size
    before_ctime = File.stat(@targetfile).ctime

    # Run etch
    #puts "Running directory script with no output"
    run_etch(@server, @testroot)

    # Verify that etch didn't do anything to the file
    assert_equal(before_size, File.stat(@targetfile).size, 'directory script with no output size comparison')
    assert_equal(before_ctime, File.stat(@targetfile).ctime, 'directory script with no output ctime comparison')

    #
    # Run a test of using a script to delete
    #

    FileUtils.mkdir_p("#{@repodir}/source/#{@targetfile}")
    File.open("#{@repodir}/source/#{@targetfile}/config.xml", 'w') do |file|
      file.puts <<-EOF
        <config>
          <delete>
            <overwrite_directory/>
            <script>delete.script</script>
          </delete>
        </config>
      EOF
    end

    File.open("#{@repodir}/source/#{@targetfile}/delete.script", 'w') do |file|
      file.puts("@contents << 'true'")
    end

    # Run etch
    #puts "Running delete script test"
    run_etch(@server, @testroot)

    # Verify that the file was removed
    assert(!File.exist?(@targetfile) && !File.symlink?(@targetfile), 'delete script')

    #
    # Run a test where the script doesn't output anything in delete
    # context
    #

    # Recreate the target file
    origcontents = "This is the original text\n"
    File.open(@targetfile, 'w') do |file|
      file.write(origcontents)
    end

    FileUtils.mkdir_p("#{@repodir}/source/#{@targetfile}")
    File.open("#{@repodir}/source/#{@targetfile}/config.xml", 'w') do |file|
      file.puts <<-EOF
        <config>
          <delete>
            <script>delete.script</script>
          </delete>
        </config>
      EOF
    end

    File.open("#{@repodir}/source/#{@targetfile}/delete.script", 'w') do |file|
      file.puts('true')
    end

    # Gather some stats about the file before we run etch
    before_size = File.stat(@targetfile).size
    before_ctime = File.stat(@targetfile).ctime

    # Run etch
    #puts "Running delete script with no output"
    run_etch(@server, @testroot)

    # Verify that etch didn't do anything to the file
    assert_equal(before_size, File.stat(@targetfile).size, 'delete script with no output size comparison')
    assert_equal(before_ctime, File.stat(@targetfile).ctime, 'delete script with no output ctime comparison')
  end

  def teardown
    remove_repository(@repodir)
    FileUtils.rm_rf(@testroot)
    FileUtils.rm_rf(@targetfile)
  end
end

