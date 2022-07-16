{% skip_file if flag?(:without_openssl) %}

require "./spec_helper"

describe "Sabo::Tabby::SSL" do
  it "should create a OpenSSL::SSL::Context::Server instance" do
    ssl = Sabo::Tabby::SSL.new
    keys = Path[__DIR__, "keys"]

    ssl.key_file = (keys / "openssl.key").to_s
    ssl.cert_file = (keys / "openssl.crt").to_s

    ssl.context.should be_a(OpenSSL::SSL::Context::Server)
  end

  it "should raise an OpenSSL::Error if either key or cert can't be found" do
    ssl = Sabo::Tabby::SSL.new

    expect_raises(OpenSSL::Error) do
      ssl.key_file = "unknown.key"
    end

    expect_raises(OpenSSL::Error) do
      ssl.cert_file = "unknown.crt"
    end
  end
end
