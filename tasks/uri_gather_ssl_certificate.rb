require 'socket'
require 'openssl'

class UriGatherSslCertTask  < BaseTask

  include Task::Web

  def metadata
    { :version => "1.0",
      :name => "uri_gather_ssl_certificate",
      :pretty_name => "URI Gather SSL Certificate",
      :authors => ["jcran"],
      :description => "Grab the SSL certificate from an application server",
      :references => [],
      :allowed_types => ["Uri"],
      :example_entities => [{:type => "Uri", :attributes => {:name => "http://www.intrigue.io"}}],
      :allowed_options => [],
      :created_types => ["DnsRecord","SslCertificate"]
    }
  end

  def run
    super

    uri = _get_entity_attribute "name"
    hostname = URI.parse(uri).host
    port = 443

    begin
      Timeout.timeout(20) do
        # Create a socket and connect
        tcp_client = TCPSocket.new hostname, port
        ssl_client = OpenSSL::SSL::SSLSocket.new tcp_client

        # Grab the cert
        ssl_client.connect

        # Parse the cert
        cert = OpenSSL::X509::Certificate.new(ssl_client.peer_cert)

        # Check the subjectAltName property, and if we have names, here, parse them.
        cert.extensions.each do |ext|
          if ext.oid =~ /subjectAltName/

            alt_names = ext.value.split(",").collect do |x|
              x.gsub(/DNS:/,"").strip
            end

            alt_names.each do |alt_name|
              _create_entity "DnsRecord", { :name => alt_name }
            end

          end
        end

        # Close the sockets
        ssl_client.sysclose
        tcp_client.close

        # Create an SSL Certificate entity
        _create_entity "SslCertificate", {  :name => cert.subject,
                                            :text => cert.to_text }
      end
    rescue Timeout::Error
      @task_log.log "Timed out"
    rescue OpenSSL::SSL::SSLError => e
      @task_log.error "Caught an error: #{e}"
    rescue Errno::ECONNRESET => e
      @task_log.error "Caught an error: #{e}"
    rescue Errno::ECONNREFUSED => e
      @task_log.error "Caught an error: #{e}"
    rescue RuntimeError => e
      @task_log.error "Caught an error: #{e}"
    end


  end

end
