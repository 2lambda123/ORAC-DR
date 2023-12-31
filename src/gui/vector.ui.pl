# interface generated by SpecTcl (Perl enabled) version 1.1
# from /home/timj/oracdr/gui/vector.ui
# For use with Tk402.002, using the grid geometry manager

sub vector_ui {
	my($root) = @_;

	# widget creation

	my($frame_2) = $root->Frame (
		-borderwidth => '2',
	);
	my($frame_4) = $root->Frame (
		-relief => 'groove',
	);
	my($frame_1) = $root->Frame (
	);
	my($label_4) = $root->Label (
		-foreground => 'black',
		-text => 'File Suffix:',
	);
	my($suffixentry) = $root->Entry (
		-textvariable => \$STATUS{VECTOR}{SUFFIX},
		-width => '8',
	);
	my($label_7) = $root->Label (
		-foreground => 'black',
		-text => 'Tool:',
	);
	my($toolmenu) = $root->Menubutton (
		-relief => 'ridge',
		-text => 'no',
		-textvariable => \$STATUS{VECTOR}{TOOL},
		-width => '10',
	);
	my($label_9) = $root->Label (
		-foreground => 'black',
		-text => 'Window:',
	);
	my($windowmenu) = $root->Menubutton (
		-relief => 'ridge',
		-text => 'no',
		-textvariable => \$STATUS{VECTOR}{WINDOW},
	);
	my($label_10) = $root->Label (
		-foreground => 'black',
		-text => 'Region:',
	);
	my($regionmenu) = $root->Menubutton (
		-relief => 'ridge',
		-text => 'no',
		-textvariable => \$STATUS{VECTOR}{REGION},
	);
	my($label_11) = $root->Label (
		-foreground => 'black',
		-text => 'X: ',
	);
	my($radiobutton_1) = $root->Radiobutton (
		-text => 'Autoscale',
		-value => '1',
		-variable => \$STATUS{VECTOR}{XAUTOSCALE},
	);
	my($radiobutton_5) = $root->Radiobutton (
		-text => 'Set:',
		-value => '0',
		-variable => \$STATUS{VECTOR}{XAUTOSCALE},
	);
	my($label_15) = $root->Label (
		-foreground => 'black',
		-text => 'xmin',
	);
	my($entry_2) = $root->Entry (
		-textvariable => \$STATUS{VECTOR}{XMIN},
		-width => '12',
	);
	my($label_18) = $root->Label (
		-foreground => 'black',
		-text => 'xmax',
	);
	my($entry_5) = $root->Entry (
		-textvariable => \$STATUS{VECTOR}{XMAX},
		-width => '12',
	);
	my($label_13) = $root->Label (
		-foreground => 'black',
		-text => 'Y: ',
	);
	my($radiobutton_3) = $root->Radiobutton (
		-text => 'Autoscale',
		-value => '1',
		-variable => \$STATUS{VECTOR}{YAUTOSCALE},
	);
	my($radiobutton_6) = $root->Radiobutton (
		-text => 'Set:',
		-value => '0',
		-variable => \$STATUS{VECTOR}{YAUTOSCALE},
	);
	my($label_16) = $root->Label (
		-foreground => 'black',
		-text => 'ymin',
	);
	my($entry_3) = $root->Entry (
		-textvariable => \$STATUS{VECTOR}{YMIN},
		-width => '12',
	);
	my($label_19) = $root->Label (
		-foreground => 'black',
		-text => 'ymax',
	);
	my($entry_6) = $root->Entry (
		-textvariable => \$STATUS{VECTOR}{YMAX},
		-width => '12',
	);
	my($label_14) = $root->Label (
		-foreground => 'black',
		-text => 'Z: ',
	);
	my($radiobutton_4) = $root->Radiobutton (
		-text => 'Autoscale',
		-value => '1',
		-variable => \$STATUS{VECTOR}{ZAUTOSCALE},
	);
	my($radiobutton_7) = $root->Radiobutton (
		-text => 'Set:',
		-value => '0',
		-variable => \$STATUS{VECTOR}{ZAUTOSCALE},
	);
	my($label_17) = $root->Label (
		-foreground => 'black',
		-text => 'zmin',
	);
	my($entry_4) = $root->Entry (
		-textvariable => \$STATUS{VECTOR}{ZMIN},
		-width => '12',
	);
	my($label_20) = $root->Label (
		-foreground => 'black',
		-text => 'zmax',
	);
	my($entry_7) = $root->Entry (
		-textvariable => \$STATUS{VECTOR}{ZMAX},
		-width => '12',
	);
	my($message_1) = $root->Message (
		-text => 'Ang',
	);
	my($entry_8) = $root->Entry (
		-textvariable => \$STATUS{VECTOR}{ANGROT},
		-width => '12',
	);
	my($button_8) = $root->Button (
		-text => 'Modify',
	);
	my($button_4) = $root->Button (
		-padx => '20',
		-text => 'Revert',
	);
	my($button_7) = $root->Button (
		-text => 'Add',
	);

	# widget commands

	$button_8->configure(
		-command => sub { modify_current('VECTOR') }
	);
	$button_4->configure(
		-command => sub { &set_default_status('VECTOR'); }
	);
	$button_7->configure(
		-command => sub {add_entry('VECTOR') }
	);

	# Geometry management

	$frame_2->grid(
		-in => $root,
		-column => '1',
		-row => '2',
		-sticky => 'w'
	);
	$frame_4->grid(
		-in => $root,
		-column => '1',
		-row => '3',
		-sticky => 'e'
	);
	$frame_1->grid(
		-in => $root,
		-column => '1',
		-row => '1'
	);
	$label_4->grid(
		-in => $frame_1,
		-column => '1',
		-row => '1'
	);
	$suffixentry->grid(
		-in => $frame_1,
		-column => '2',
		-row => '1',
		-sticky => 'w'
	);
	$label_7->grid(
		-in => $frame_1,
		-column => '3',
		-row => '1'
	);
	$toolmenu->grid(
		-in => $frame_1,
		-column => '4',
		-row => '1',
		-sticky => 'ew'
	);
	$label_9->grid(
		-in => $frame_1,
		-column => '5',
		-row => '1'
	);
	$windowmenu->grid(
		-in => $frame_1,
		-column => '6',
		-row => '1',
		-sticky => 'ew'
	);
	$label_10->grid(
		-in => $frame_1,
		-column => '7',
		-row => '1'
	);
	$regionmenu->grid(
		-in => $frame_1,
		-column => '8',
		-row => '1',
		-sticky => 'ew'
	);
	$label_11->grid(
		-in => $frame_2,
		-column => '1',
		-row => '1'
	);
	$radiobutton_1->grid(
		-in => $frame_2,
		-column => '2',
		-row => '1'
	);
	$radiobutton_5->grid(
		-in => $frame_2,
		-column => '3',
		-row => '1'
	);
	$label_15->grid(
		-in => $frame_2,
		-column => '4',
		-row => '1'
	);
	$entry_2->grid(
		-in => $frame_2,
		-column => '5',
		-row => '1'
	);
	$label_18->grid(
		-in => $frame_2,
		-column => '6',
		-row => '1'
	);
	$entry_5->grid(
		-in => $frame_2,
		-column => '7',
		-row => '1'
	);
	$label_13->grid(
		-in => $frame_2,
		-column => '1',
		-row => '2'
	);
	$radiobutton_3->grid(
		-in => $frame_2,
		-column => '2',
		-row => '2'
	);
	$radiobutton_6->grid(
		-in => $frame_2,
		-column => '3',
		-row => '2'
	);
	$label_16->grid(
		-in => $frame_2,
		-column => '4',
		-row => '2'
	);
	$entry_3->grid(
		-in => $frame_2,
		-column => '5',
		-row => '2'
	);
	$label_19->grid(
		-in => $frame_2,
		-column => '6',
		-row => '2'
	);
	$entry_6->grid(
		-in => $frame_2,
		-column => '7',
		-row => '2'
	);
	$label_14->grid(
		-in => $frame_2,
		-column => '1',
		-row => '3'
	);
	$radiobutton_4->grid(
		-in => $frame_2,
		-column => '2',
		-row => '3'
	);
	$radiobutton_7->grid(
		-in => $frame_2,
		-column => '3',
		-row => '3'
	);
	$label_17->grid(
		-in => $frame_2,
		-column => '4',
		-row => '3'
	);
	$entry_4->grid(
		-in => $frame_2,
		-column => '5',
		-row => '3'
	);
	$label_20->grid(
		-in => $frame_2,
		-column => '6',
		-row => '3'
	);
	$entry_7->grid(
		-in => $frame_2,
		-column => '7',
		-row => '3'
	);
	$message_1->grid(
		-in => $frame_2,
		-column => '6',
		-row => '4'
	);
	$entry_8->grid(
		-in => $frame_2,
		-column => '7',
		-row => '4'
	);
	$button_8->grid(
		-in => $frame_4,
		-column => '1',
		-row => '1'
	);
	$button_4->grid(
		-in => $frame_4,
		-column => '2',
		-row => '1'
	);
	$button_7->grid(
		-in => $frame_4,
		-column => '4',
		-row => '1'
	);

	# Resize behavior management

	# container $frame_2 (rows)
	$frame_2->gridRowconfigure(1, -weight  => 0, -minsize  => 30);
	$frame_2->gridRowconfigure(2, -weight  => 0, -minsize  => 30);
	$frame_2->gridRowconfigure(3, -weight  => 0, -minsize  => 30);
	$frame_2->gridRowconfigure(4, -weight  => 0, -minsize  => 30);

	# container $frame_2 (columns)
	$frame_2->gridColumnconfigure(1, -weight => 0, -minsize => 76);
	$frame_2->gridColumnconfigure(2, -weight => 0, -minsize => 39);
	$frame_2->gridColumnconfigure(3, -weight => 0, -minsize => 30);
	$frame_2->gridColumnconfigure(4, -weight => 0, -minsize => 30);
	$frame_2->gridColumnconfigure(5, -weight => 0, -minsize => 30);
	$frame_2->gridColumnconfigure(6, -weight => 0, -minsize => 47);
	$frame_2->gridColumnconfigure(7, -weight => 0, -minsize => 2);

	# container $frame_4 (rows)
	$frame_4->gridRowconfigure(1, -weight  => 0, -minsize  => 30);

	# container $frame_4 (columns)
	$frame_4->gridColumnconfigure(1, -weight => 0, -minsize => 30);
	$frame_4->gridColumnconfigure(2, -weight => 0, -minsize => 37);
	$frame_4->gridColumnconfigure(3, -weight => 0, -minsize => 2);
	$frame_4->gridColumnconfigure(4, -weight => 0, -minsize => 30);

	# container $root (rows)
	$root->gridRowconfigure(1, -weight  => 0, -minsize  => 30);
	$root->gridRowconfigure(2, -weight  => 0, -minsize  => 33);
	$root->gridRowconfigure(3, -weight  => 0, -minsize  => 30);

	# container $root (columns)
	$root->gridColumnconfigure(1, -weight => 0, -minsize => 34);

	# container $frame_1 (rows)
	$frame_1->gridRowconfigure(1, -weight  => 0, -minsize  => 30);

	# container $frame_1 (columns)
	$frame_1->gridColumnconfigure(1, -weight => 0, -minsize => 30);
	$frame_1->gridColumnconfigure(2, -weight => 0, -minsize => 59);
	$frame_1->gridColumnconfigure(3, -weight => 0, -minsize => 30);
	$frame_1->gridColumnconfigure(4, -weight => 0, -minsize => 20);
	$frame_1->gridColumnconfigure(5, -weight => 0, -minsize => 30);
	$frame_1->gridColumnconfigure(6, -weight => 0, -minsize => 37);
	$frame_1->gridColumnconfigure(7, -weight => 0, -minsize => 33);
	$frame_1->gridColumnconfigure(8, -weight => 0, -minsize => 32);

	# additional interface code

create_menus('VECTOR', $toolmenu, $windowmenu, $regionmenu);



	# end additional interface code
}
