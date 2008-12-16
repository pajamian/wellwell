UserTag form Order name
UserTag form AddAttr
UserTag form Routine <<EOR
sub {
	my ($name, $opt) = @_;
	my ($form_name, @out);

	$Tag->perl({tables => 'form_series form_elements form_attributes'});

	$form_name = $opt->{component};

	if ($name) {
		# produce one form out of a series
		my ($series_qtd, $set, $pos, $pos_max);

		$series_qtd = $Db{form_series}->quote($name);
		$set = $Db{form_series}->query({sql => qq{select * from form_series where name = $series_qtd order by position}, hashref => 1});
		
		# ensure that we don't run out of the form series
		$pos_max = @$set;

		unless (ref($Session->{form_series}) eq 'HASH') {
			$Session->{form_series} = {};
		}

		if ($CGI->{series} eq $name) {
			if ($Session->{form_series}->{$name} <= $pos_max) {
				$Session->{form_series}->{$name} += 1;
			}
		} else {
			$Session->{form_series}->{$name} = 1;
		}
		$pos = $Session->{form_series}->{$name};

		for (@$set) {
			if ($_->{position} == $pos - 1) {
				if ($_->{profile}) {
					unless ($Tag->run_profile({name => $_->{profile}, cgi => 1})) {
						$Session->{form_series}->{$name} -= 1;
						$Tag->update('values');
						return $Tag->form({series => $name, 
							label => $_->{label},
							component => $_->{component}, 
							from_file => $_->{from_file},
							template => $opt->{template}});
					}
				}
				if ($_->{save}) {
					my (@save, $tag, $ret);

					@save = split(/,/, $_->{save});
					$tag = shift(@save);
					$ret = $Tag->$tag(@save);
				}
			} 
			elsif ($_->{position} == $pos) {
				if ($_->{load}) {
					my (@load, $tag, $ret);

					@load = split(/,/, $_->{load});
					$tag = shift(@load);
					$ret = $Tag->$tag(@load);
				}
				return $Tag->form({series => $name, label => $_->{label},
					component => $_->{component},
					from_file => $_->{from_file},
					template => $opt->{template}});
			}
		}

		$Tag->error({name => 'form', set => "Missing form $name, position $pos"});
		return;
	}

	if ($opt->{from_file}) {
		# load component from file
		my $content;

		$content = $Tag->include("$Variable->{MV_COMPONENT_DIR}/$opt->{component}");
		push(@out, $content);
	} else {
		push(@out, '<fieldset>');

		# label for form elements
		if ($opt->{label}) {
			if ($opt->{anchor}) {
				push(@out, qq{<legend><a name="$opt->{anchor}">$opt->{label}</a></legend>});
			}
			else {
				push(@out, qq{<legend>$opt->{label}</legend>});
			}
		}

		if ($opt->{prepend}) {
			push(@out, $opt->{prepend});
		}
	
		# form elements
		my ($elset, $attrset, $qcomp);

		$qcomp = $Db{form_elements}->quote($opt->{component});

		$elset = $Db{form_elements}->query({sql => qq{select name,label,widget from form_elements where component = $qcomp order by priority desc}, hashref => 1});

		for my $elref (@$elset) {
			# fetch attributes for form element
			my %attributes;
		
			$attrset = $Db{form_attributes}->query(q{select attribute,value from form_attributes where name = '%s' and component = '%s'}, $elref->{name}, $opt->{component});
			for (@$attrset) {
				$attributes{$_->[0]} = $_->[1];
			}

			# determine current value
			my $value = $Tag->filter('encode_entities', $Values->{$elref->{name}});

			# "display" form element
			my $label = '';
			my $append = '';
		
			if (delete $attributes{profile} eq 'required') {
				$append = q{<span class="required">*</span>};
			}

			if ($elref->{label} =~ /\S/) {
				$label = "$elref->{label}$append$opt->{appendlabel}";
			}
			push (@out, qq{<label for="$elref->{name}">$label</label>});
			push (@out, $Tag->display({name => $elref->{name},
									   type => $elref->{widget} || 'text',
									   value => $value,
									   form_name => $form_name,
									   %attributes}));
			push (@out, '<br/>');
		}

		push(@out, '</fieldset>');
	}

	unless ($opt->{partial}) {
		my ($out, $url, $action, $sid, $series, $body, $page);

		# read template
		my ($t_name, $t_file, $t_template);

		$t_name = $opt->{template} || 'form';
		$t_file = "$Variable->{MV_TEMPLATE_DIR}/$t_name";
		
		unless ($t_template = $Tag->file($t_file)) {
			$Tag->error({name => 'form_template',
				set => "Invalid template $t_name"});
			return;
		}

		if ($CGI->{mv_nextpage}) {
			$page = $CGI->{mv_nextpage};
		}
		else {
			$page = substr($Session->{last_url},1);
		}

		$action = $Tag->area({href => $page,
							  match_security => 1});
		$sid = $Tag->form_session_id();

		if ($opt->{series}) {
			$series = qq{<input type="hidden" name="series" value="$opt->{series}">
};	
		}

		my %fhash;

		$fhash{top} = <<EOT;
<form action="$action" method="post" name="$form_name">
$series$sid
EOT

		$fhash{body} = join("\n", @out);
		$fhash{submit} = q{<input type="submit" name="submit" value="OK">};
		$fhash{bottom} = q{</form>};

		$out = $Tag->uc_attr_list({hash => \%fhash, body => $t_template});

		return $out;
	}
	
	return join("\n", @out);
}
EOR