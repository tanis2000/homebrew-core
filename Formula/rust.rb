class Rust < Formula
  desc "Safe, concurrent, practical language"
  homepage "https://www.rust-lang.org/"

  stable do
    url "https://static.rust-lang.org/dist/rustc-1.15.0-src.tar.gz"
    sha256 "f655e4fac9c2abb93eb579e29c408e46052c0e74b7655cd222c63c6743457673"

    resource "cargo" do
      url "https://github.com/rust-lang/cargo.git",
          :tag => "0.16.0",
          :revision => "6e0c18cccc8b0c06fba8a8d76486f81a792fb420"
    end

    resource "racer" do
      url "https://github.com/phildawes/racer/archive/2.0.5.tar.gz"
      sha256 "370e8e2661b379185667001884b51bdc4b414abdc27bb9671513c1912ad8be25"
    end
  end

  bottle do
    rebuild 1
    sha256 "82f74db87c045a45d280aa00cc554c6131d80295d7f232bfd4712547aaa3a56b" => :sierra
    sha256 "8ca5809af70971d0e8bd8b1a1e7c91f757d6e37d3b371ad9a029d1d05a42bb73" => :el_capitan
    sha256 "96f0d599f21e398ad897badad2c6b8da9ee025f879e38242cf397846a3f249da" => :yosemite
  end

  head do
    url "https://github.com/rust-lang/rust.git"

    resource "cargo" do
      url "https://github.com/rust-lang/cargo.git"
    end
  end

  option "with-llvm", "Build with brewed LLVM. By default, Rust's LLVM will be used."
  option "with-racer", "Build Racer code completion tool, and retain Rust sources."

  depends_on "cmake" => :build
  depends_on "pkg-config" => :run
  depends_on "llvm" => :optional
  depends_on "openssl"
  depends_on "libssh2"

  conflicts_with "multirust", :because => "both install rustc, rustdoc, cargo, rust-lldb, rust-gdb"

  # According to the official readme, GCC 4.7+ is required
  fails_with :gcc_4_0
  fails_with :gcc
  ("4.3".."4.6").each do |n|
    fails_with :gcc => n
  end

  resource "cargobootstrap" do
    url "https://s3.amazonaws.com/rust-lang-ci/cargo-builds/fbeea902d2c9a5be6d99cc35681565d8f7832592/cargo-nightly-x86_64-apple-darwin.tar.gz"
    version "2016-12-15"
    sha256 "ad6c31b41fef1d68e4523eb7d090fe8103848f30eb5ac8cba5128b7c11ed23fc"
  end

  def install
    args = ["--prefix=#{prefix}"]
    args << "--disable-rpath" if build.head?
    args << "--enable-clang" if ENV.compiler == :clang
    args << "--llvm-root=#{Formula["llvm"].opt_prefix}" if build.with? "llvm"
    if build.head?
      args << "--release-channel=nightly"
    else
      args << "--release-channel=stable"
    end
    system "./configure", *args
    system "make"
    system "make", "install"

    resource("cargobootstrap").stage do
      system "./install.sh", "--prefix=#{buildpath}/cargobootstrap"
    end
    ENV.prepend_path "PATH", buildpath/"cargobootstrap/bin"

    resource("cargo").stage do
      system "./configure", "--prefix=#{prefix}", "--local-rust-root=#{prefix}",
                            "--enable-optimize"
      system "make"
      system "make", "install"
    end

    if build.with? "racer"
      resource("racer").stage do
        ENV.prepend_path "PATH", bin
        cargo_home = buildpath/"cargo_home"
        cargo_home.mkpath
        ENV["CARGO_HOME"] = cargo_home
        system bin/"cargo", "build", "--release", "--verbose"
        (libexec/"bin").install "target/release/racer"
        (bin/"racer").write_env_script(libexec/"bin/racer", :RUST_SRC_PATH => pkgshare/"rust_src")
      end
      # Remove any binary files; as Homebrew will run ranlib on them and barf.
      rm_rf Dir["src/{llvm,test,librustdoc,etc/snapshot.pyc}"]
      (pkgshare/"rust_src").install Dir["src/*"]
    end

    rm_rf prefix/"lib/rustlib/uninstall.sh"
    rm_rf prefix/"lib/rustlib/install.log"
  end

  test do
    system "#{bin}/rustdoc", "-h"
    (testpath/"hello.rs").write <<-EOS.undent
    fn main() {
      println!("Hello World!");
    }
    EOS
    system "#{bin}/rustc", "hello.rs"
    assert_equal "Hello World!\n", `./hello`
    system "#{bin}/cargo", "new", "hello_world", "--bin"
    assert_equal "Hello, world!",
                 (testpath/"hello_world").cd { `#{bin}/cargo run`.split("\n").last }
  end
end
