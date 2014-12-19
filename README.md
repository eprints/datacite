DateCiteDoi - A plugin to mint DataCite DOIs to eprints
========================================================

Requirements
-------------

In order to use the DataCite API the plugin requires the following perl libraries on to of EPrints requirements.

```
use LWP;
use Crypt::SSLeay;
```

Installation
-------------

Install the plugin from the bazaar and edit the following config files.

```
z_datacite_core.pl
z_datacitedoi.pl
```

Configuration 
-------------

z_datacitedoi.pl

This config file contains all the configurable settings for the plugin, see comments bellow:

```perl
#Enable the plugin
$c->{plugins}{"Export::DataCiteXML"}{params}{disable} = 0;
$c->{plugins}{"Event::DataCiteEvent"}{params}{disable} = 0;

#which field do use for the doi
$c->{datacitedoi}{eprintdoifield} = "id_number";

#When should you register/update doi info.
$c->{datacitedoi}{eprintstatus} = {inbox=>0,buffer=>1,archive=>1,deletion=>0};

#set these (you will get the from data site)
# doi = {prefix}/{repoid}/{eprintid}
$c->{datacitedoi}{prefix} = "10.5072";
$c->{datacitedoi}{repoid} = $c->{host};
$c->{datacitedoi}{apiurl} = "https://test.datacite.org/mds/";
$c->{datacitedoi}{user} = "USER";
$c->{datacitedoi}{pass} = "PASS";

# datacite requires a Publisher 
# The name of the entity that holds, archives, publishes, 
# prints, distributes, releases, issues, or produces the 
# resource. This property will be used to formulate the 
# citation, so consider the prominence of the role.
# eg World Data Center for Climate (WDCC);   
$c->{datacitedoi}{publisher} = "Eprints Repo";

# need to map eprint type (article, dataset etc) to ResourceType
# Controled list http://schema.datacite.org/meta/kernel-2.2/doc/DataCite-MetadataKernel_v2.2.pdf
# where v is the ResourceType and a is the resourceTypeGeneral
$c->{datacitedoi}{typemap}{article} = {v=>'Article',a=>'Text'};
$c->{datacitedoi}{typemap}{book_section} = {v=>'BookSection',a=>'Text'};
$c->{datacitedoi}{typemap}{monograph} = {v=>'Monograph',a=>'Text'};
$c->{datacitedoi}{typemap}{thesis} = {v=>'Thesis',a=>'Text'};
$c->{datacitedoi}{typemap}{book} = {v=>'Book',a=>'Text'};
$c->{datacitedoi}{typemap}{patent} = {v=>'Patent',a=>'Text'};
$c->{datacitedoi}{typemap}{artefact} = {v=>'Artefact',a=>'PhysicalObject'};
$c->{datacitedoi}{typemap}{performance} = {v=>'Performance',a=>'Event'};
$c->{datacitedoi}{typemap}{composition} = {v=>'Composition',a=>'Sound'};
$c->{datacitedoi}{typemap}{image} = {v=>'Image',a=>'Image'};
$c->{datacitedoi}{typemap}{experiment} = {v=>'Experiment',a=>'Text'};
$c->{datacitedoi}{typemap}{teaching_resource} = {v=>'TeachingResourse',a=>'InteractiveResource'};
$c->{datacitedoi}{typemap}{other} = {v=>'Misc',a=>'Collection'};
$c->{datacitedoi}{typemap}{dataset} = {v=>'Dataset',a=>'Dataset'};
$c->{datacitedoi}{typemap}{audio} = {v=>'Audio',a=>'Sound'};
$c->{datacitedoi}{typemap}{video} = {v=>'Video',a=>'Film'};
```

z_datacite_core.pl

Adds the minting plugin, by default it the plugin will run when ever the status (draft,review,deposit,delete) changes.
The plugin will then run asynchronously after the change using the eprints queue so the datacite registration wont affect the users view.

```perl
# Adds the minting plugin to the EP_TRIGGER_STATUS_CHANGE
$c->add_dataset_trigger( "eprint", EP_TRIGGER_STATUS_CHANGE , sub {
       my ( %params ) = @_;
 
       my $repository = %params->{repository};
 
       return undef if (!defined $repository);

       if (defined %params->{dataobj}) {
               my $dataobj = %params->{dataobj};
               my $eprint_id = $dataobj->id;

			$repository->dataset( "event_queue" )->create_dataobj({
						                       pluginid => "Event::DataCiteEvent",
						                       action => "datacite_doi",
						                       params => [$dataobj->internal_uri],
						               });
		               });
     }
 
});
```
How it works
-------------

/lib/plugins/EPrints/Plugin/Event/DataCiteEvent.pm
This is added to the queue and actually mints the doi.

/lib/plugins/EPrints/Plugin/Export/DataCiteXML.pm
This exports the metadata xml required for minting, this can be used independently and through the user interface. 

By default the plugin uses the following mapping:
```xml
<?xml version="1.0"?>
<resource xmlns="http://datacite.org/schema/kernel-2.2" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://datacite.org/schema/kernel-2.2 http://schema.datacite.org/meta/kernel-2.2/metadata.xsd">
	<identifier identifierType="DOI">[[From Config: $c->{datacitedoi}{prefix}/$c->{datacitedoi}{repoid]]/{{Eprintid}}</identifier>
	<creators>
		<creator>
			<creatorName>[[From Eprint: Creators]]</creatorName>
		</creator>
	</creators>
	<titles>
		<title>[[From Eprint: Title]]/title>
	</titles>
	<publisher>[[From Config: $c->{datacitedoi}{publisher}]]</publisher>
	<publicationYear>[[From Eprint: Year]]</publicationYear>
	<subjects>
		<subject>[[From Eprints: Subjects]]</subject>
	</subjects>
	<resourceType resourceTypeGeneral="[[Mapped From Config: $c->{datacitedoi}{typemap}]]">[[Mapped From Config: $c->{datacitedoi}{typemap}]]</resourceType>
	<alternateIdentifiers>
		<alternateIdentifier alternateIdentifierType="URL">[[From Eprints: Subjects]]</alternateIdentifier>
	</alternateIdentifiers>
</resource>
```

