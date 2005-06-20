package Slim::Buttons::Input::Bar;

# $Id$
# SlimServer Copyright (c) 2001-2004 Sean Adams, Slim Devices Inc.
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License,
# version 2.

use strict;

use Slim::Buttons::Common;
use Slim::Utils::Misc;
use Slim::Display::Display;

Slim::Buttons::Common::addMode('INPUT.Bar', getFunctions(), \&setMode);

###########################
#Button mode specific junk#
###########################
our %functions = (
	#change character at cursorPos (both up and down)
	'up' => sub {
			my ($client,$funct,$functarg) = @_;
			changePos($client,1,$funct);
		}
	,'down' => sub {
			my ($client,$funct,$functarg) = @_;
			changePos($client,-1,$funct);
		}
	#call callback procedure
	,'exit' => sub {
			my ($client,$funct,$functarg) = @_;
			if (!defined($functarg) || $functarg eq '') {
				$functarg = 'exit'
			}
			exitInput($client,$functarg);
		}
	,'passback' => sub {
			my ($client,$funct,$functarg) = @_;
			my $parentMode = $client->param('parentMode');
			if (defined($parentMode)) {
				Slim::Hardware::IR::executeButton($client,$client->lastirbutton,$client->lastirtime,$parentMode);
			}
		}
);

sub changePos {
	my ($client, $dir,$funct) = @_;
	my $listRef = $client->param('listRef');
	my $listIndex = $client->param('listIndex');

	if (($listIndex == 0 && $dir < 0) || ($listIndex == (scalar(@$listRef) - 1) && $dir > 0)) {
			#not wrapping and at end of list
			return;
	}
	
	my $accel = 8; # Hz/sec
	my $rate = 50; # Hz
	my $inc = 1;
	my $mid = $client->param('mid')||0;
	my $min = $client->param('min')||0;
	my $max = $client->param('max')||100;
	my $midpoint = ($mid-$min)/($max-$min)*(scalar(@$listRef) - 1);
	my $newposition;
	
	if (Slim::Hardware::IR::holdTime($client) > 0) {
		$inc *= Slim::Hardware::IR::repeatCount($client,$rate,$accel);
	}
	
	my $currVal = $listIndex;
	
	if ($dir == 1) {
		$newposition = $listIndex+$inc;
		if ($currVal < ($midpoint - .5) && ($currVal + $inc) >= ($midpoint - .5)) {
			# make the midpoint sticky by resetting the start of the hold
			$newposition = $midpoint;
			Slim::Hardware::IR::resetHoldStart($client);
		}
	} else {
		$newposition = $listIndex-$inc;
		if ($currVal > ($midpoint + .5) && ($currVal - $inc) <= ($midpoint + .5)) {
			# make the midpoint sticky by resetting the start of the hold
			$newposition = $midpoint;
			Slim::Hardware::IR::resetHoldStart($client);
		}
	}

	$newposition = scalar(@$listRef)-1 if $newposition > scalar(@$listRef)-1;
	$newposition = 0 if $newposition < 0;
	my $valueRef = $client->param('valueRef');
	$$valueRef = $listRef->[$newposition];
	$client->param('listIndex',int($newposition));
	my $onChange = $client->param('onChange');
	if (ref($onChange) eq 'CODE') {
		my $onChangeArgs = $client->param('onChangeArgs');
		my @args;
		push @args, $client if $onChangeArgs =~ /c/i;
		push @args, $$valueRef if $onChangeArgs =~ /v/i;
		$onChange->(@args);
	}
	$client->update();
}

sub lines {
	my $client = shift;
	# These parameters are used when calling this function from Slim::Display::Display
	my $value = shift;
	my $header = shift;
	my $args = shift;

	my $min = $args->{'min'};
	my $mid = $args->{'mid'};
	my $max = $args->{'max'};
	my $noOverlay = $args->{'noOverlay'} || 0;

	my ($line1, $line2);

	my $valueRef = $client->param('valueRef');
	$valueRef = \$value if defined $value;
	
	my $listIndex = $client->param('listIndex');

	if (defined $header) {
		$line1 = $header;
	} else {
		$line1 = Slim::Buttons::Input::List::getExtVal($client,$$valueRef,$listIndex,'header');
		if ($client->param('stringHeader') && Slim::Utils::Strings::stringExists($line1)) {
			$line1 = $client->string($line1);
		}
		if (ref $client->param('headerValue') eq "CODE") {
			$line1 .= Slim::Buttons::Input::List::getExtVal($client,$$valueRef,$listIndex,'headerValue');
		}
	}
	
	$min = $client->param('min') || 0 unless defined $min;
	$mid = $client->param('mid') || 0 unless defined $mid;
	$max = $client->param('max') || 100 unless defined $max;

	my $val = $max == $min ? 0 : int(($$valueRef - $min)*100/($max-$min));
	my $fullstep = 1 unless $client->param('smoothing');

	$line2 = $client->sliderBar($client->displayWidth(), $val,$max == $min ? 0 :($mid-$min)/($max-$min)*100,$fullstep);

	if ($client->linesPerScreen() == 1) {
		if ($client->param('barOnDouble')) {
			$line1 = $line2;
			$line2 = '';
		} else {
			$line2 = $line1;
		}
	}
	my @overlay = $noOverlay ? undef : Slim::Buttons::Input::List::getExtVal($client,$valueRef,$listIndex,'overlayRef');
	return ($line1,$line2,@overlay);
}


sub getFunctions {
	return \%functions;
}

sub setMode {
	my $client = shift;
	#my $setMethod = shift;
	#possibly skip the init if we are popping back to this mode
	#if ($setMethod ne 'pop') {
		if (!init($client)) {
			Slim::Buttons::Common::popModeRight($client);
		}
	#}
	$client->lines(\&lines);
}
# set unsupplied parameters to the defaults
# header = '' # message displayed on top line, can be a scalar, a code ref
	# , or an array ref to a list of scalars or code refs
# headerArgs = CV
# stringHeader = undef # if true, put the value of header through the string function
	# before displaying it.
# headerValue = undef
	# set to 'scaled' to show the current value modified by the increment in parentheses
	# set to 'unscaled' to show the current value in parentheses
	# set to a codeRef which returns a string to be shown after the standard header
# headerValueArgs = CV
# headerValueUnit = '' # Set to a units symbol to be displayed before the closing paren
# valueRef =  # reference to value to be selected
# callback = undef # function to call to exit mode
# overlayRef = undef
# overlayRefArgs = CV
# onChange = undef
# onChangeArgs = CV
# min = 0 # minimum value for slider scale
# max = 100 #maximum value for slider scale
# mid = 0 # midpoint value for marking the division point for a balance bar.
# midIsZero = 1 # set to 0 if you don't want the mid value to be interpreted as zero
# increment = 2.5 # step value for each bar character or button press.
# barOnDouble = 0 # set to 1 if the bar is preferred when using large text.
# smoothing = 0 # set to 1 if you want the character display to use custom chars to smooth the movement of the bar.

sub init {
	my $client = shift;
	if (!defined($client->param('parentMode'))) {
		my $i = -2;
		while ($client->modeStack->[$i] =~ /^INPUT./) { $i--; }
		$client->param('parentMode',$client->modeStack->[$i]);
	}
	if (!defined($client->param('header'))) {
		$client->param('header','');
	}
	if (!defined($client->param('min'))) {
		$client->param('min',0);
	}
	if (!defined($client->param('mid'))) {
		$client->param('mid',0);
	}	
	if (!defined($client->param('midIsZero'))) {
		$client->param('midIsZero',1);
	}	
	if (!defined($client->param('max'))) {
		$client->param('max',100);
	}
	if (!defined($client->param('increment'))) {
		$client->param('increment',2.5);
	}
	if (!defined($client->param('barOnDouble'))) {
		$client->param('barOnDouble',0);
	}


	my $min = $client->param('min');
	my $mid = $client->param('mid');
	my $max = $client->param('max');
	my $step = $client->param('increment');

	my $listRef;
	my $i;
	my $j=0;
	for ($i = $min;$i<=$max;$i=$i + $step) {
		$listRef->[$j] = $i;
		$j++;
	}
	$client->param('listRef',$listRef);
	my $listIndex = $client->param('listIndex');
	my $valueRef = $client->param('valueRef');
	if (!defined($listIndex)) {
		$listIndex = 0;
	} elsif ($listIndex > $#$listRef) {
		$listIndex = $#$listRef;
	}
	while ($listIndex < 0) {
		$listIndex += scalar(@$listRef);
	}
	if (!defined($valueRef)) {
		$$valueRef = $listRef->[$listIndex];
		$client->param('valueRef',$valueRef);
	} elsif (!ref($valueRef)) {
		my $value = $valueRef
		$valueRef = \$value;
		$client->param('valueRef',$valueRef);
	}
	if ($$valueRef != $listRef->[$listIndex]) {
		my $newIndex;
		for ($newIndex = 0; $newIndex < scalar(@$listRef); $newIndex++) {
			last if $$valueRef <= $listRef->[$newIndex];
		}
		if ($newIndex < scalar(@$listRef)) {
			$listIndex = $newIndex;
		} else {
			$$valueRef = $listRef->[$listIndex];
		}
	}

	$client->param('listIndex',$listIndex);

	if (!defined($client->param('onChangeArgs'))) {
		$client->param('onChangeArgs','CV');
	}
	if (!defined($client->param('headerArgs'))) {
		$client->param('headerArgs','CV');
	}
	if (!defined($client->param('overlayRefArgs'))) {
		$client->param('overlayRefArgs','CV');
	}
	my $headerValue = lc($client->param('headerValue') || '');
	if ($headerValue eq 'scaled') {
		$client->param('headerValue',\&scaledValue);
	} elsif ($headerValue eq 'unscaled') {
		$client->param('headerValue',\&unscaledValue);
	}
	if (!defined($client->param('headerValueArgs'))) {
		$client->param('headerValueArgs','CV');
	}
	if (!defined($client->param('headerValueUnit'))) {
		$client->param('headerValueUnit','');
	}
	return 1;
}

sub scaledValue {
	my $client = shift;
	my $value = shift;

	if ($client->param('midIsZero')) {
		$value -= $client->param('mid');
	}

	my $increment = $client->param('increment');
	$value /= $increment if $increment;
	
	$value = int($value + 0.5);

	my $unit = $client->param('headerValueUnit');
	$unit = '' unless defined $unit;
	
	return " ($value$unit)"	
}

sub unscaledValue {
	my $client = shift;
	my $value = shift;
	
	if ($client->param('midIsZero')) {
		$value -= $client->param('mid');
	}

	$value = int($value + 0.5);

	my $unit = $client->param('headerValueUnit');
	$unit = '' unless defined $unit;
	
	return " ($value$unit)"	
}

sub exitInput {
	my ($client,$exitType) = @_;
	my $callbackFunct = $client->param('callback');
	if (!defined($callbackFunct) || !(ref($callbackFunct) eq 'CODE')) {
		if ($exitType eq 'right') {
			$client->bumpRight();
		} elsif ($exitType eq 'left') {
			Slim::Buttons::Common::popModeRight($client);
		} else {
			Slim::Buttons::Common::popMode($client);
		}
		return;
	}
	$callbackFunct->(@_);
}

1;
