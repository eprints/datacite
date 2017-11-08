=head1 NAME

EPrints::Plugin::Event::DataCiteEvent

=cut

package EPrints::Plugin::Event::DataCiteEvent;

use EPrints::Plugin::Event;
use LWP;
use Crypt::SSLeay;
use HTTP::Headers::Util;

@ISA = qw( EPrints::Plugin::Event );

sub datacite_doi
 {
       my( $self, $dataobj) = @_;

		my $repository = $self->repository();

		#Check object status first.... TODO Make work for dataobj == doument (just in case)
		my $shoulddoi = $repository->get_conf( "datacitedoi", "eprintstatus",  $dataobj->value( "eprint_status" ));
		#Check Doi Status
		if(!$shoulddoi){
			$repository->log("Attempt to coin DOI for item that is not in the required area (see \$c->{datacitedoi}->{eprintstatus})");
			return EPrints::Const::HTTP_INTERNAL_SERVER_ERROR;
		}

		my $thisdoi = $self->coin_doi($repository,$dataobj);
		#coin_doi may return an event error code if no prefix present assume this is the case
		my $prefix = $repository->get_conf( "datacitedoi", "prefix");
		return $thisdoi if($thisdoi !~ /^$prefix/);

		#Pass doi into Export::DataCiteXML...
		my $xml = $dataobj->export( "DataCiteXML", doi=>$thisdoi );
		return $xml if($xml =~ /^\d+$/); #just a number? coin_doi has passed back an error code pass it on...

		#print STDERR "XML: $xml\n";
		my $url = $repository->get_conf( "datacitedoi", "apiurl");
		$url.="/" if($url !~ /\/$/); #attach slash if config has forgotten
		my $user_name = $repository->get_conf( "datacitedoi", "user");
		my $user_pw = $repository->get_conf( "datacitedoi", "pass");

		#register metadata;
		my($response_content, $response_code) =  datacite_request("POST", $url."metadata", $user_name, $user_pw, $xml, "application/xml;charset=UTF-8");
		if($response_code !~ /20(1|0)/){
			$repository->log("Metadata response from datacite api: $response_code: $response_content");
			$repository->log("BTW the \$doi was:\n$thisdoi");
			return EPrints::Const::HTTP_INTERNAL_SERVER_ERROR;
		}
		#register doi
		my $repo_url =$dataobj->uri();
		#RM special override to allow testing from "wrong" domain
		if(defined $repository->get_conf( "datacitedoi", "override_url")){
			$repo_url = $repository->get_conf( "datacitedoi", "override_url");
			$repo_url.= $dataobj->internal_uri;
		}
 		my $doi_reg = "doi=$thisdoi\nurl=".$repo_url;
		($response_content, $response_code)= datacite_request("POST", $url."doi", $user_name, $user_pw, $doi_reg, "text/plain; charset=utf8");
		if($response_code  !~ /20(1|0)/){
			$repository->log("Registration response from datacite api: $response_code: $response_content");
			$repository->log("BTW the \$doi_reg was:\n$doi_reg");
			return EPrints::Const::HTTP_INTERNAL_SERVER_ERROR;
		}

		#now it is safe to set DOI value.
		my $eprintdoifield = $repository->get_conf( "datacitedoi", "eprintdoifield");
		$dataobj->set_value($eprintdoifield, $thisdoi);
		$dataobj->commit();
		#success
		return undef;
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
    $headers, Encode::encode_utf8( $content )
  );
  $req->authorization_basic($user_name, $user_pw);

  # pass request to the user agent and get a response back
  my $ua = LWP::UserAgent->new;
  my $res = $ua->request($req);

  return ($res->content(),$res->code());
}

#RM lets do the DOI coining somewhere (reasonably) accessible
sub coin_doi {

       my( $self, $repository, $dataobj) = @_;

	#RM zero padds eprintid as per config
	my $z_pad = $repository->get_conf( "datacitedoi", "zero_padding") || 0;
	my $id  = sprintf("%0".$z_pad."d", $dataobj->id);
	#Check for custom delimiters
	my ($delim1, $delim2) = @{$repository->get_conf( "datacitedoi", "delimiters")};
	#default to slash
	$delim1 = "/" if(!defined $delim1);
	#second defaults to first
	$delim2 = $delim1 if(!defined $delim2);
	#construct the DOI string
	my $prefix = $repository->get_conf( "datacitedoi", "prefix");
	my $thisdoi = $prefix.$delim1.$repository->get_conf( "datacitedoi", "repoid").$delim2.$id;

	my $eprintdoifield = $repository->get_conf( "datacitedoi", "eprintdoifield");

	#Custom DOIS
	#if DOI field is set attempt to use that if config allows
	if($dataobj->exists_and_set( $eprintdoifield) ){

		#if config does not allow ... bail
		if( !$repository->get_conf( "datacitedoi", "allow_custom_doi" ) ){
			$repository->log("DOI is already set and custom overrides are disaallowed by config");
			return EPrints::Const::HTTP_INTERNAL_SERVER_ERROR;
		}
		#we are allowed (check prefix just in case)
		$thisdoi = $dataobj->get_value( $eprintdoifield );
    # AH commented out because when there is an existing DOI (e.g. one issued by the publisher)
    # the condition is always true and therefore, existing DOI becomes an empty string
		# if($thisdoi !~ /^$prefix/){
		# 	$repository->log("Prefix does not match ($prefix) for custom DOI: $thisdoi");
		# 	$dataobj->set_value($eprintdoifield, ""); #unset the bad DOI!!
		# 	$dataobj->commit();
		# 	return EPrints::Const::HTTP_INTERNAL_SERVER_ERROR;
		# }#We'll leave Datacite to do any further syntax checking etc...
	}

	return $thisdoi;
}
1;
