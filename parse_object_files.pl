use Data::Dumper;
$nodenum=1;

my $database = {};
foreach(@ARGV) {
	open(my $in,"<",$_) or next;
	$database = loadFiles($database,$in);
}
$Data::Dumper::Sortkeys = 1;

analysis($database);


#print Dumper($database); exit 0;
my $main="main";
print "digraph \"$main\" {\n";
$main=$database->{$main};
$DB::single=1;
outCallChain( "main", $main );
#print Dumper($database); exit 0;
outNodes("TOP",$database->{"#Files"});

print "\n}\n";


open(DB,">","care.db");
print DB Dumper($database);
close(DB);

exit 0;

sub loadFiles {
	my $database = shift;
	my $in=shift;
	my $currentFunction={};
	my $fun="???";
	my $file="???";

	sub fun { 
	    $fun = shift; 
	    $currentFunction = \$database->{$fun};

	    push @{$$currentFunction->{"#File"}}, $file;
	    push @{$database->{"#Files"}->{$file}->{"#Fun"}},$fun;
	}


	while (<$in>) {
	    chomp;
	    $file = $1 if /^(.*):\s+file\s+format/;
	    fun($1) if /^[0-9a-f]+\s<([^>]+)>/;
	    $$currentFunction->{$1}++ if /: R_[A-Z0-9_]+\s+([^\.]\S+?)(\+0x[0-9a-f]+)?$/;
	    $$currentFunction->{$1}++ if /:\s.* <(\S+)\@plt>/;
	}
	return $database;
}


sub analysis2 {
	my $database = shift;
	print "Analysis per file\n";

	my $main="main";
	foreach (keys %{$database->{$main}}) {
			next if /^#/;
			#$database->{"# Tree"}->{$main}->{$_} = $database->{
			#}
		}
	my @files= @{$database->{$main}->{"#File"}};
	foreach ( @files ) {
		last;
		my @calls = @{$database->{"#Files"}->{$_}->{"#Calls"}};
		foreach ( @calls ) {
			$database->{"# Tree"}->{$main}->{$_}=1;
		}
	}
}


sub analysis {
	my $database = shift;
	foreach $fun ( keys %$database ) {
		next if  $fun =~ /^#/;
		my $thisFunction  = $database->{$fun};
		foreach ( keys %$thisFunction ) { 
			next if /^#/;
			my $calledFunction = \$thisFunction->{$_};
			#next if ref $f->{$_} eq "HASH";
			next unless ref $thisFunction->{$_}  eq "";
			next unless defined( $database->{$_} ); 
			$$calledFunction  = \$database->{$_};
			my @calledFiles = @{$database->{$_}->{"#File"}};
			foreach (@calledFiles) {
				$thisFunction->{"#CalledFrom"}->{$_}++;
			}
			my $thisFile = $database->{"#Files"}->{$thisFunction};
			foreach $file ( @{$thisFunction->{"#File"}}) {
				foreach $called ( @calledFiles ) {
					$database->{"#Files"}->{$file}->{"#Calls"}->{$called}++;
				}
			}

		}
	}
}



sub outCallChain {
    my $files;
    out(@_);
    # Fix DB info about used files
    while( my ($f,$cnt) = each %$files ) {
	    $database->{"#Files"}->{$f}->{"#Called"} += $cnt;
    }
    
    sub out {
	    my ( $name, $itm ) = @_;  # print("CK:$name\n");
	    return if $itm->{"#Done"}++;
	    foreach( @{$itm->{"#File"}}) {
		    $files->{$_}++;
	    }
	    while ( my ( $k, $v ) = each %$itm ) {
		next if $k =~ /^#/;
		next unless ref $v eq "REF";
		print "\"$name\" -> \"$k\";\n";
		out( $k, $$v );
	    }
	}
}


sub outNodes {
    my ( $name, $itm ) = @_;  # print("CK:$name\n");
    my $files = $itm;
    while ( my ( $k, $v ) = each %$files ) {
	    next unless $v->{"#Called"};
	    my $f = $k; 
	    $f =~ s,^.*/,,;
	    print <<EOM;
	    rankdir="LR";
	    subgraph cluster_$nodenum {
	    rankdir="TB";
			style=filled;
		color=lightgrey;
		node [style=filled,color=white];
		label = "$f";
EOM
	    print "   ".join(";\n   ", @{$v->{"#Fun"}}).";\n";
	    print "}\n";
	    $nodenum++;
    }
}








