=head1 NAME

EPrints::Plugin::Event::DataCiteEvent

=cut

package EPrints::Plugin::Event::DataCiteEvent;
 
use EPrints::Plugin::Event;
use LWP;
use Crypt::SSLeay;

@ISA = qw( EPrints::Plugin::Event );
 
sub datacite_doi
 {
       my( $self, $repository, $eprint_id ) = @_;

		my $eprint =  $repository->eprint(  $eprint_id );

		my $thisdoi = $repository->get_conf( "datacitedoi", "prefix")."/". $repository->get_conf( "datacitedoi", "repoid")."/".$eprint_id;
	
		my $eprintdoifield = $repository->get_conf( "datacitedoi", "eprintdoifield");
		
		my $task;
		
		my $shoulddoi = $repository->get_conf( "datacitedoi", "eprintstatus",  $eprint->value( "eprint_status" ));
		
		#Check Doi Status
		if(!$shoulddoi) return;
	
	
	
		
		#check if doi has been set;
		if( $eprint->exists_and_set( $eprintdoifield )) {
			if( $eprint->value( $eprintdoifield ) ne $thisdoi ){
				#Skipping because its has a diff doi;
				return;
			}
		}else{
			$eprint->update( {
			    $eprintdoifield => $thisdoi
			  });
			$eprint->commit();
		}
		
		
		my $xml = $eprint->export( "DataCiteXML" );
		my $url = $repository->get_conf( "datacitedoi", "apiurl");
		my $user_name = $repository->get_conf( "datacitedoi", "user");
		my $user_pw = $repository->get_conf( "datacitedoi", "pass");
		
		#register metadata;
		$response_code =  datacite_request("POST", $url."metadata", $user_name, $user_pw, $xml, "application/xml;charset=UTF-8");
		
		#register doi
		my $doi_reg = "doi=$thisdoi\nurl=".$eprint->get_url();
		$response_code =  datacite_request("POST", $url."doi", $user_name, $user_pw, $doi_reg, "text/plain;charset=UTF-8");

}


sub datacite_request {
  my ($method, $url, $user_name, $user_pw, $content, $content_type) = @_;

  # build request
  my $headers = HTTP::Headers->new(
    'Accept'  => 'application/xml',
    'Content-Type' => $content_type
  );
  my $req = HTTP::Request->new(
    $method => $url,
    $headers, $content
  );
  $req->authorization_basic($user_name, $user_pw);

  # pass request to the user agent and get a response back
  my $ua = LWP::UserAgent->new;
  my $res = $ua->request($req);

  return $res->content();
}




1;