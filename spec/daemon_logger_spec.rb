require 'stringio'

describe ServerEngine::DaemonLogger do
  before { FileUtils.mkdir_p("tmp") }
  before { FileUtils.rm_f("tmp/se1.log") }
  before { FileUtils.rm_f Dir["tmp/se1.log.**"] }
  before { FileUtils.rm_f("tmp/se2.log") }

  subject { DaemonLogger.new("tmp/se1.log", level: 'trace') }

  it 'reopen' do
    subject.warn "ABCDEF"
    File.open('tmp/se1.log', "w") {|f| }
    subject.warn "test2"

    File.read('tmp/se1.log').should_not =~ /ABCDEF/
  end

  it 'reset path' do
    subject.logdev = 'tmp/se2.log'
    subject.warn "test"

    File.read('tmp/se2.log').should =~ /test$/
  end

  it 'default level is debug' do
    subject.debug 'debug'
    File.read('tmp/se1.log').should =~ /debug$/
  end

  it 'level set by int' do
    subject.level = Logger::FATAL
    subject.level.should == Logger::FATAL
    subject.trace?.should == false
    subject.debug?.should == false
    subject.info?.should  == false
    subject.warn?.should  == false
    subject.error?.should == false
    subject.fatal?.should == true

    subject.level = Logger::ERROR
    subject.level.should == Logger::ERROR
    subject.trace?.should == false
    subject.debug?.should == false
    subject.info?.should  == false
    subject.warn?.should  == false
    subject.error?.should == true
    subject.fatal?.should == true

    subject.level = Logger::WARN
    subject.level.should == Logger::WARN
    subject.trace?.should == false
    subject.debug?.should == false
    subject.info?.should  == false
    subject.warn?.should  == true
    subject.error?.should == true
    subject.fatal?.should == true

    subject.level = Logger::INFO
    subject.level.should == Logger::INFO
    subject.trace?.should == false
    subject.debug?.should == false
    subject.info?.should  == true
    subject.warn?.should  == true
    subject.error?.should == true
    subject.fatal?.should == true

    subject.level = Logger::DEBUG
    subject.level.should == Logger::DEBUG
    subject.trace?.should == false
    subject.debug?.should == true
    subject.info?.should  == true
    subject.warn?.should  == true
    subject.error?.should == true
    subject.fatal?.should == true

    subject.level = DaemonLogger::TRACE
    subject.level.should == DaemonLogger::TRACE
    subject.trace?.should == true
    subject.debug?.should == true
    subject.info?.should  == true
    subject.warn?.should  == true
    subject.error?.should == true
    subject.fatal?.should == true
  end

  it 'level set by string' do
    subject.level = 'fatal'
    subject.level.should == Logger::FATAL

    subject.level = 'error'
    subject.level.should == Logger::ERROR

    subject.level = 'warn'
    subject.level.should == Logger::WARN

    subject.level = 'info'
    subject.level.should == Logger::INFO

    subject.level = 'debug'
    subject.level.should == Logger::DEBUG

    subject.level = 'trace'
    subject.level.should == DaemonLogger::TRACE
  end

  it 'unknown level' do
    lambda { subject.level = 'unknown' }.should raise_error(ArgumentError)
  end

  it 'rotation' do
    log = DaemonLogger.new("tmp/se1.log", level: 'trace', log_rotate_age: 3, log_rotate_size: 10000)
    # 100 bytes
    log.warn "test1"*20
    File.exist?("tmp/se1.log").should == true
    File.exist?("tmp/se1.log.0").should == false

    # 10000 bytes
    100.times { log.warn "test2"*20 }
    File.exist?("tmp/se1.log").should == true
    File.exist?("tmp/se1.log.0").should == true
    File.read("tmp/se1.log.0") =~ /test2$/

    # 10000 bytes
    100.times { log.warn "test3"*20 }
    File.exist?("tmp/se1.log").should == true
    File.exist?("tmp/se1.log.1").should == true
    File.exist?("tmp/se1.log.2").should == false

    log.warn "test4"*20
    File.read("tmp/se1.log.0") =~ /test5$/
  end

  it 'IO logger' do
    io = StringIO.new
    io.should_receive(:write)
    io.should_not_receive(:reopen)

    log = DaemonLogger.new(io)
    log.debug "stdout logging test"
    log.reopen!
  end

  it 'inter-process locking on rotation' do
    log = DaemonLogger.new("tmp/se1.log", level: 'trace', log_rotate_age: 3, log_rotate_size: 10)
    r, w = IO.pipe
    $stderr = w # To capture #warn output in DaemonLogger
    pid1 = Process.fork do
      10.times do
        log.info '0' * 15
      end
    end
    pid2 = Process.fork do
      10.times do
        log.info '0' * 15
      end
    end
    Process.waitpid pid1
    Process.waitpid pid2
    w.close
    stderr = r.read
    r.close
    $stderr = STDERR
    stderr.should_not =~ /(log shifting failed|log writing failed|log rotation inter-process lock failed)/
  end
end
