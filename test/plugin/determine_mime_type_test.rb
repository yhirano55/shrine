require "test_helper"
require "shrine/plugins/determine_mime_type"
require "stringio"
require "open3"

describe Shrine::Plugins::DetermineMimeType do
  before do
    @uploader = uploader { plugin :determine_mime_type }
    @shrine = @uploader.class
  end

  describe ":file analyzer" do
    before do
      @shrine.plugin :determine_mime_type, analyzer: :file
    end

    it "determines MIME type from file contents" do
      mime_type = @shrine.determine_mime_type(image)
      assert_equal "image/jpeg", mime_type
    end

    it "gives as as much of the file to standard input as needed" do
      mime_type = @shrine.determine_mime_type(fakeio("a" * 5*1024*1024))
      assert_equal "text/plain", mime_type
    end

    it "is able to determine MIME type for non-files" do
      mime_type = @shrine.determine_mime_type(fakeio(image.read))
      assert_equal "image/jpeg", mime_type
    end

    it "returns nil for empty IOs" do
      mime_type = @shrine.determine_mime_type(fakeio(""))
      assert_nil mime_type
    end

    it "raises error if file command is not found" do
      Open3.stubs(:popen3).raises(Errno::ENOENT)
      assert_raises(Shrine::Error) { @shrine.determine_mime_type(image) }
    end

    it "raises error if file command failed" do
      failed_result = Open3.popen3("file", "--foo")
      Open3.stubs(:popen3).yields(failed_result)
      assert_raises(Shrine::Error) { @shrine.determine_mime_type(image) }
    end

    it "fowards any warnings to stderr" do
      assert_output(nil, "") { @shrine.determine_mime_type(image) }

      stderr_result = Open3.popen3("echo stderr 1>&2")
      Open3.stubs(:popen3).yields(stderr_result)
      assert_output(nil, "stderr\n") { @shrine.determine_mime_type(image) }
    end
  end

  describe ":filemagic analyzer" do
    before do
      @shrine.plugin :determine_mime_type, analyzer: :filemagic
    end

    it "determines MIME type from file contents" do
      mime_type = @shrine.determine_mime_type(image)
      assert_equal "image/jpeg", mime_type
    end

    it "returns nil for empty IOs" do
      mime_type = @shrine.determine_mime_type(fakeio(""))
      assert_nil mime_type
    end
  end unless RUBY_ENGINE == "jruby" || ENV["CI"]

  describe ":mimemagic analyzer" do
    before do
      @shrine.plugin :determine_mime_type, analyzer: :mimemagic
    end

    it "extracts MIME type of any IO" do
      mime_type = @shrine.determine_mime_type(image)
      assert_equal "image/jpeg", mime_type
    end

    it "returns nil for unidentified MIME types" do
      mime_type = @shrine.determine_mime_type(fakeio("😃"))
      assert_nil mime_type
    end

    it "returns nil for empty IOs" do
      mime_type = @shrine.determine_mime_type(fakeio(""))
      assert_nil mime_type
    end
  end

  describe ":mime_types analyzer" do
    before do
      @shrine.plugin :determine_mime_type, analyzer: :mime_types
    end

    it "extract MIME type from the file extension" do
      mime_type = @shrine.determine_mime_type(fakeio(filename: "image.png"))
      assert_equal "image/png", mime_type

      mime_type = @shrine.determine_mime_type(image)
      assert_equal "image/jpeg", mime_type
    end

    it "returns nil on unkown extension" do
      mime_type = @shrine.determine_mime_type(fakeio(filename: "file.foo"))
      assert_nil mime_type
    end

    it "returns nil when input is not a file" do
      mime_type = @shrine.determine_mime_type(fakeio)
      assert_nil mime_type
    end

    it "returns nil for empty IOs" do
      mime_type = @shrine.determine_mime_type(fakeio(""))
      assert_nil mime_type
    end
  end

  describe ":mini_mime analyzer" do
    before do
      @shrine.plugin :determine_mime_type, analyzer: :mini_mime
    end

    it "extract MIME type from the file extension" do
      mime_type = @shrine.determine_mime_type(fakeio(filename: "image.png"))
      assert_equal "image/png", mime_type

      mime_type = @shrine.determine_mime_type(image)
      assert_equal "image/jpeg", mime_type
    end

    it "returns nil on unkown extension" do
      mime_type = @shrine.determine_mime_type(fakeio(filename: "file.foo"))
      assert_nil mime_type
    end

    it "returns nil when input is not a file" do
      mime_type = @shrine.determine_mime_type(fakeio)
      assert_nil mime_type
    end

    it "returns nil for empty IOs" do
      mime_type = @shrine.determine_mime_type(fakeio(""))
      assert_nil mime_type
    end
  end

  describe ":default analyzer" do
    before do
      @shrine.plugin :determine_mime_type, analyzer: :default
    end

    it "extracts MIME type from #content_type" do
      mime_type = @shrine.determine_mime_type(fakeio(content_type: "foo/bar"))
      assert_equal "foo/bar", mime_type
    end
  end

  it "has a default analyzer" do
    mime_type = @shrine.determine_mime_type(fakeio(image.read))
    assert_equal "image/jpeg", mime_type
  end

  it "allows passing a custom extractor" do
    @shrine.plugin :determine_mime_type, analyzer: ->(io) { "foo/bar" }
    mime_type = @shrine.determine_mime_type(image)
    assert_equal "foo/bar", mime_type

    @shrine.plugin :determine_mime_type, analyzer: ->(io, analyzers) { analyzers[:file].call(io) }
    mime_type = @shrine.determine_mime_type(image)
    assert_equal "image/jpeg", mime_type
  end

  it "always rewinds the file" do
    @shrine.plugin :determine_mime_type, analyzer: ->(io) { io.read }
    @shrine.determine_mime_type(file = image)
    assert_equal 0, file.pos
  end

  it "provides access to mime type analyzers" do
    analyzers = @shrine.mime_type_analyzers

    mime_type = analyzers[:file].call(io = fakeio("content", filename: "file.json"))
    assert_equal "text/plain", mime_type
    assert_equal "content", io.read

    mime_type = analyzers[:mime_types].call(io = fakeio("content", filename: "file.json"))
    assert_equal "application/json", mime_type
    assert_equal "content", io.read
  end
end
