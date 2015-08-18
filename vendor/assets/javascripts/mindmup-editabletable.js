/*global $, window*/
$.fn.editableTableWidget = function (options) {
	'use strict';
	return $(this).each(function () {

		var buildDefaultOptions = function () {
				var opts = $.extend({}, $.fn.editableTableWidget.defaultOptions);
				opts.editor = opts.editor.clone();
				return opts;
			},
			activeOptions = $.extend(buildDefaultOptions(), options),
			ARROW_LEFT = 37, ARROW_UP = 38, ARROW_RIGHT = 39, ARROW_DOWN = 40, ENTER = 13, ESC = 27, TAB = 9,
			element = $(this),
			editor = activeOptions.editor.attr('id','activeInput').css('position', 'absolute').hide().appendTo(element.parent()), //.attr('id','activeInput') added in manually by Steve to facility auto suggest plugin
			active,
			showEditor = function (select) {
				active = element.find('td:focus');

				activeInputMealType = active.parent().data('type'); // added this in manually by Steve to facilitate auto suggest plugin
				activeInputMealID = active.parent().data('id'); // added this in manually by Steve to facilitate auto suggest plugin


				if (active.length && !active.hasClass('disable_editable')) { //the !active.hasClass('disable_editable') is manually added by Steve to disable editing of certain cells

					if (active.hasClass('meal_name')) {
						var category = activeInputMealType.indexOf('reen') > -1 ? "Green" : activeInputMealType;
			          $.ajax({
			            url: suggestionPath+'?category='+category,
			            type: 'GET',
			            dataType: 'JSON'
			          }).done(function(data){
			          	autoSuggest = data;
						$('#meal_suggestion').css({top:active.offset().top+active.height()+18, left:active.offset().left});
						$('#meal_suggestion').empty();
						autoSuggest.forEach(function(mi){
							var m = mi.data[0];
							$('#meal_suggestion').append("<div class='padder-v padder b-b autoSuggestItem' style='width:100%;' data-id='"+m.id+"' data-selectionid='"+activeInputMealID+"'><span style='font-weight:bold;'>"+m.name+"</span> | Rating: "+m.rating+" - Last Made: "+m.last_made+"<br>Veg: "+m.veg+"<br>Carb: "+m.carb+"</div>");

							$('.autoSuggestItem').off('click').on('click',function(){
								var plotToID = $(this).data('selectionid');
								var getThisID = $(this).data('id');
								var row = $('tr').filter(function(){return $(this).data('id') == plotToID});

						          $.ajax({
						            url: individualMealPullPath+'?meal_id='+getThisID,
						            type: 'GET',
						            dataType: 'JSON'
						          }).done(function(data){
						          	var meal_name = data.meal_name;
						          	var protein = data.protein;
						          	var carb = data.carb;
						          	var veggie = data.veggie;
						          	var extra = data.extra;
						          	var notes = data.notes;
						          	var dish = data.dish;

						          	row.find('td').eq(3).html(meal_name);
						          	row.find('td').eq(4).html(protein);
						          	row.find('td').eq(5).html(carb);
						          	row.find('td').eq(6).html(veggie);
						          	row.find('td').eq(7).html(extra);
						          	row.find('td').eq(8).html(notes);
						          	row.find('td').eq(9).find('input').prop('checked',dish);

				                  $('#change_notification').removeClass("hidden");
				                  $('#update_menu').html("Save changes").removeClass("disabled");

						          });

								$('#meal_suggestion').addClass('hidden');
								$('.scrollable').off('scroll');
								$('html').off('click');
							});

						});			          	
			           });						

						$('#meal_suggestion').removeClass('hidden');
						$('.scrollable').off('scroll').on('scroll',function(){
							$('#meal_suggestion').css({top:active.offset().top+active.height()+18, left:active.offset().left});
						});

						$('.scrollable > div, header, #nav, table > thead, .c1, .c9, .c4, .c5, .c6, .c7, .c8, .c10, .c11').off('click').on('click',function(){
							$('#meal_suggestion').addClass('hidden');
							$('.scrollable').off('scroll');							
						})

					} else {
						$('#meal_suggestion').addClass('hidden');
						$('.scrollable').off('scroll');
					}

					editor.val(active.text())
						.removeClass('error')
						.show()
						.offset(active.offset())
						.css(active.css(activeOptions.cloneProperties))
						.width(active.width())
						.height(active.height())
						.focus();
					if (select) {
						editor.select();
					}
				}


			},
			setActiveText = function () {
				var text = editor.val(),
					evt = $.Event('change'),
					originalContent;
				if (active.text() === text || editor.hasClass('error')) {
					return true;
				}
				originalContent = active.html();
				active.text(text).trigger(evt, text);
				if (evt.result === false) {
					active.html(originalContent);
				}
			},
			movement = function (element, keycode) {
				if (keycode === ARROW_RIGHT) {
					$('#meal_suggestion').addClass('hidden'); //added in by Steve manually to hide the suggestion box
					$('.scrollable').off('scroll'); //added in by Steve manually to hide the suggestion box
					return element.next('td');
				} else if (keycode === ARROW_LEFT) {
					$('#meal_suggestion').addClass('hidden'); //added in by Steve manually to hide the suggestion box
					$('.scrollable').off('scroll'); //added in by Steve manually to hide the suggestion box
					return element.prev('td');
				} else if (keycode === ARROW_UP) {
					$('#meal_suggestion').addClass('hidden'); //added in by Steve manually to hide the suggestion box
					$('.scrollable').off('scroll'); //added in by Steve manually to hide the suggestion box
					return element.parent().prev().children().eq(element.index());
				} else if (keycode === ARROW_DOWN) {
					$('#meal_suggestion').addClass('hidden'); //added in by Steve manually to hide the suggestion box
					$('.scrollable').off('scroll'); //added in by Steve manually to hide the suggestion box
					return element.parent().next().children().eq(element.index());
				}
				return [];
			};
		editor.blur(function () {
			setActiveText();
			editor.hide();
		}).keydown(function (e) {
			if (e.which === ENTER) {
				setActiveText();
				editor.hide();
				active.focus();
				e.preventDefault();
				e.stopPropagation();
				$('#meal_suggestion').addClass('hidden'); //added in by Steve manually to hide the suggestion box
				$('.scrollable').off('scroll'); //added in by Steve manually to hide the suggestion box
			} else if (e.which === ESC) {
				editor.val(active.text());
				e.preventDefault();
				e.stopPropagation();
				editor.hide();
				active.focus();
				$('#meal_suggestion').addClass('hidden'); //added in by Steve manually to hide the suggestion box
				$('.scrollable').off('scroll'); //added in by Steve manually to hide the suggestion box
			} else if (e.which === TAB) {
				active.focus();
				$('#meal_suggestion').addClass('hidden'); //added in by Steve manually to hide the suggestion box
				$('.scrollable').off('scroll'); //added in by Steve manually to hide the suggestion box
			} else if (this.selectionEnd - this.selectionStart === this.value.length) {
				var possibleMove = movement(active, e.which);
				if (possibleMove.length > 0) {
					possibleMove.focus();
					e.preventDefault();
					e.stopPropagation();
				}
			}
		})
		.on('input paste', function () {
			var evt = $.Event('validate');
			active.trigger(evt, editor.val());
			if (evt.result === false) {
				editor.addClass('error');
			} else {
				editor.removeClass('error');
			}
		});
		element.off('click keypress dblclick').on('click keypress dblclick', showEditor)
		.css('cursor', 'pointer')
		.keydown(function (e) {
			var prevent = true,
				possibleMove = movement($(e.target), e.which);
			if (possibleMove.length > 0) {
				possibleMove.focus();
			} else if (e.which === ENTER) {
				showEditor(false);
			} else if (e.which === 17 || e.which === 91 || e.which === 93) {
				showEditor(true);
				prevent = false;
			} else {
				prevent = false;
			}
			if (prevent) {
				e.stopPropagation();
				e.preventDefault();
			}
		});

		element.find('td').prop('tabindex', 1);

		$(window).on('resize', function () {
			if (editor.is(':visible')) {
				editor.offset(active.offset())
				.width(active.width())
				.height(active.height());
			}
		});
	});

};
$.fn.editableTableWidget.defaultOptions = {
	cloneProperties: ['padding', 'padding-top', 'padding-bottom', 'padding-left', 'padding-right',
					  'text-align', 'font', 'font-size', 'font-family', 'font-weight',
					  'border', 'border-top', 'border-bottom', 'border-left', 'border-right'],
	editor: $('<input>')
};

