package comic;

# $Id$
# Date: 21/11/2002
# Author: glen@delfi.ee
#
# Fetches from various websites comics and sends them away with email.
# Can do email with image attachments and just with url to direct resource.

use strict;

sub new {
	my $self = shift;
	my $class = ref($self) || $self;
	my $props = shift;

	my $this = { $props ? %$props : () };
	bless($this, $class);
}


sub fetch_data {
	my $this = shift;

	$this->{debug} = 1 if -t STDERR;

	my @data;
	foreach (keys(%plugin::plugins)) {
		my $p = new $_;
		$p->get_url();
		$p->fetch_gfx();
		push(@data, $p->get_data());
	}

	$this->{data} = \@data;
}

sub compose_mail {
	my $this = shift;

	# make html part
	use MIME::Entity;
	my $entity = build MIME::Entity
		'Subject'			=> 'DAILY: comics at estonian web',
		'Reply-To'			=> 'glen@delfi.ee',
		'List-Unsubscribe:'	=> '<mailto:glen-comics@delfi.ee?subject=unsub>',
		'Type'				=> 'multipart/related';


	my $body = '<!doctype html public "-//w3c//dtd html 4.0 transitional//en">
	<html>
	<table border=0 bgcolor="#ffffff" cellpadding=0 cellspacing=0 width=574>
	';

	my @data = @{ $this->{data} };
	foreach (@data) {
		foreach (values(%$_)) {
			my %h = %$_;
			next unless $h{content_id};
			$body .= sprintf("<tr><td width=100%%><img border=1 alt=\"%s\" src=cid:%s><br></td></tr>\n",
				$h{desc}, $h{content_id});
		}
	}
	print "finished\n";

	$body .= '
	</table><p>
	</html>
	';

	$entity->attach(Type => 'text/html', 'Data' => $body);

	# add attachments
	foreach (@data) {
		foreach (values(%$_)) {
			my %h = %$_;
			next unless $h{data};
			$entity->attach(
				'Type' => $h{content_type},
				'Encoding' => 'base64',
				'Content-ID' => "<$h{content_id}>",
				'Filename' => $h{filename},
				'Data' => $h{data},
			);
		}
	}

	$this->{attach} = $entity;
}

sub mailer {
	my $this = shift;
	my $ent = shift;

	my @recip = (ref $_[0] ? $_[0] : @_);


	use Mail::Mailer;

	my $hdr = $ent->head->header_hashref;
	my $body = $ent->stringify_body;
	foreach (@recip) {
		$$hdr{To} = $_;
		my $msg = new Mail::Mailer;
		my $fh = $msg->open($hdr);
		print $fh $body;
		$fh->close;
	}
}

sub mail_attach {
	my $this = shift;
	$this->mailer($this->{attach}, @_);
}

1;