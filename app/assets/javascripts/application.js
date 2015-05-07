// This is a manifest file that'll be compiled into application.js, which will include all the files
// listed below.
//
// Any JavaScript/Coffee file within this directory, lib/assets/javascripts, vendor/assets/javascripts,
// or vendor/assets/javascripts of plugins, if any, can be referenced here using a relative path.
//
// It's not advisable to add code directly here, but if you do, it'll appear at the bottom of the
// compiled file.
//
// Read Sprockets README (https://github.com/sstephenson/sprockets#sprockets-directives) for details
// about supported directives.
//
//= require jquery
//= require jquery_ujs
//= require turbolinks
//= require_tree ../../../vendor/assets/javascripts/.
//= require_tree .

/* =========================================================
 * bootstrap-slider.js v3.0.0
 * =========================================================
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 * ========================================================= */


(function( $ ) {

    var ErrorMsgs = {
        formatInvalidInputErrorMsg : function(input) {
            return "Invalid input value '" + input + "' passed in";
        },
        callingContextNotSliderInstance : "Calling context element does not have instance of Slider bound to it. Check your code to make sure the JQuery object returned from the call to the slider() initializer is calling the method"
    };

    var Slider = function(element, options) {
        var el = this.element = $(element).hide();
        var origWidth =  $(element)[0].style.width;

        var updateSlider = false;
        var parent = this.element.parent();


        if (parent.hasClass('slider') === true) {
            updateSlider = true;
            this.picker = parent;
        } else {
            this.picker = $('<div class="slider">'+
                                '<div class="slider-track">'+
                                    '<div class="slider-selection"></div>'+
                                    '<div class="slider-handle"></div>'+
                                    '<div class="slider-handle"></div>'+
                                '</div>'+
                                '<div id="tooltip" class="tooltip"><div class="tooltip-arrow"></div><div class="tooltip-inner"></div></div>'+
                                '<div id="tooltip_min" class="tooltip"><div class="tooltip-arrow"></div><div class="tooltip-inner"></div></div>'+
                                '<div id="tooltip_max" class="tooltip"><div class="tooltip-arrow"></div><div class="tooltip-inner"></div></div>'+
                            '</div>')
                                .insertBefore(this.element)
                                .append(this.element);
        }

        this.id = this.element.data('slider-id')||options.id;
        if (this.id) {
            this.picker[0].id = this.id;
        }

        if (('ontouchstart' in window) || window.DocumentTouch && document instanceof window.DocumentTouch) {
            this.touchCapable = true;
        }

        var tooltip = this.element.data('slider-tooltip')||options.tooltip;

        this.tooltip = this.picker.find('#tooltip');
        this.tooltipInner = this.tooltip.find('div.tooltip-inner');

        this.tooltip_min = this.picker.find('#tooltip_min');
        this.tooltipInner_min = this.tooltip_min.find('div.tooltip-inner');

        this.tooltip_max = this.picker.find('#tooltip_max');
        this.tooltipInner_max= this.tooltip_max.find('div.tooltip-inner');

        if (updateSlider === true) {
            // Reset classes
            this.picker.removeClass('slider-horizontal');
            this.picker.removeClass('slider-vertical');
            this.tooltip.removeClass('hide');
            this.tooltip_min.removeClass('hide');
            this.tooltip_max.removeClass('hide');

        }

        this.orientation = this.element.data('slider-orientation')||options.orientation;
        switch(this.orientation) {
            case 'vertical':
                this.picker.addClass('slider-vertical');
                this.stylePos = 'top';
                this.mousePos = 'pageY';
                this.sizePos = 'offsetHeight';
                this.tooltip.addClass('right')[0].style.left = '100%';
                this.tooltip_min.addClass('right')[0].style.left = '100%';
                this.tooltip_max.addClass('right')[0].style.left = '100%';
                break;
            default:
                this.picker
                    .addClass('slider-horizontal')
                    .css('width', origWidth);
                this.orientation = 'horizontal';
                this.stylePos = 'left';
                this.mousePos = 'pageX';
                this.sizePos = 'offsetWidth';
                this.tooltip.addClass('top')[0].style.top = -this.tooltip.outerHeight() - 14 + 'px';
                this.tooltip_min.addClass('top')[0].style.top = -this.tooltip_min.outerHeight() - 14 + 'px';
                this.tooltip_max.addClass('top')[0].style.top = -this.tooltip_max.outerHeight() - 14 + 'px';
                break;
        }

        var self = this;
        $.each(['min',
                'max',
                'step',
                'precision',
                'value',
                'reversed',
                'handle'
            ], function(i, attr) {
                if (typeof el.data('slider-' + attr) !== 'undefined') {
                    self[attr] = el.data('slider-' + attr);
                } else if (typeof options[attr] !== 'undefined') {
                    self[attr] = options[attr];
                } else if (typeof el.prop(attr) !== 'undefined') {
                    self[attr] = el.prop(attr);
                } else {
                    self[attr] = 0; // to prevent empty string issues in calculations in IE
                }
        });

        if (this.value instanceof Array) {
            if (updateSlider && !this.range) {
                this.value = this.value[0];
            } else {
                this.range = true;
            }
        } else if (this.range) {
            // User wants a range, but value is not an array
            this.value = [this.value, this.max];
        }

        this.selection = this.element.data('slider-selection')||options.selection;
        this.selectionEl = this.picker.find('.slider-selection');
        if (this.selection === 'none') {
            this.selectionEl.addClass('hide');
        }

        this.selectionElStyle = this.selectionEl[0].style;

        this.handle1 = this.picker.find('.slider-handle:first');
        this.handle1Stype = this.handle1[0].style;

        this.handle2 = this.picker.find('.slider-handle:last');
        this.handle2Stype = this.handle2[0].style;

        if (updateSlider === true) {
            // Reset classes
            this.handle1.removeClass('round triangle');
            this.handle2.removeClass('round triangle hide');
        }

        switch(this.handle) {
            case 'round':
                this.handle1.addClass('round');
                this.handle2.addClass('round');
                break;
            case 'triangle':
                this.handle1.addClass('triangle');
                this.handle2.addClass('triangle');
                break;
        }

        this.offset = this.picker.offset();
        this.size = this.picker[0][this.sizePos];
        this.formater = options.formater;
        
        this.tooltip_separator = options.tooltip_separator;
        this.tooltip_split = options.tooltip_split;

        this.setValue(this.value);

        this.handle1.on({
            keydown: $.proxy(this.keydown, this, 0)
        });
        this.handle2.on({
            keydown: $.proxy(this.keydown, this, 1)
        });

        if (this.touchCapable) {
            // Touch: Bind touch events:
            this.picker.on({
                touchstart: $.proxy(this.mousedown, this)
            });
        }
        // Bind mouse events:
        this.picker.on({
            mousedown: $.proxy(this.mousedown, this)
        });

        if(tooltip === 'hide') {
            this.tooltip.addClass('hide');
            this.tooltip_min.addClass('hide');
            this.tooltip_max.addClass('hide');
        } else if(tooltip === 'always') {
            this.showTooltip();
            this.alwaysShowTooltip = true;
        } else {
            this.picker.on({
                mouseenter: $.proxy(this.showTooltip, this),
                mouseleave: $.proxy(this.hideTooltip, this)
            });
            this.handle1.on({
                focus: $.proxy(this.showTooltip, this),
                blur: $.proxy(this.hideTooltip, this)
            });
            this.handle2.on({
                focus: $.proxy(this.showTooltip, this),
                blur: $.proxy(this.hideTooltip, this)
            });
        }

        this.enabled = options.enabled &&
                        (this.element.data('slider-enabled') === undefined || this.element.data('slider-enabled') === true);
        if(this.enabled) {
            this.enable();
        } else {
            this.disable();
        }
    };

    Slider.prototype = {
        constructor: Slider,

        over: false,
        inDrag: false,

        showTooltip: function(){
            if (this.tooltip_split === false ){
                this.tooltip.addClass('in');
            } else {
                this.tooltip_min.addClass('in');
                this.tooltip_max.addClass('in');
            }

            this.over = true;
        },

        hideTooltip: function(){
            if (this.inDrag === false && this.alwaysShowTooltip !== true) {
                this.tooltip.removeClass('in');
                this.tooltip_min.removeClass('in');
                this.tooltip_max.removeClass('in');
            }
            this.over = false;
        },

        layout: function(){
            var positionPercentages;

            if(this.reversed) {
                positionPercentages = [ 100 - this.percentage[0], this.percentage[1] ];
            } else {
                positionPercentages = [ this.percentage[0], this.percentage[1] ];
            }

            this.handle1Stype[this.stylePos] = positionPercentages[0]+'%';
            this.handle2Stype[this.stylePos] = positionPercentages[1]+'%';

            if (this.orientation === 'vertical') {
                this.selectionElStyle.top = Math.min(positionPercentages[0], positionPercentages[1]) +'%';
                this.selectionElStyle.height = Math.abs(positionPercentages[0] - positionPercentages[1]) +'%';
            } else {
                this.selectionElStyle.left = Math.min(positionPercentages[0], positionPercentages[1]) +'%';
                this.selectionElStyle.width = Math.abs(positionPercentages[0] - positionPercentages[1]) +'%';

                var offset_min = this.tooltip_min[0].getBoundingClientRect();
                var offset_max = this.tooltip_max[0].getBoundingClientRect();

                if (offset_min.right > offset_max.left) {
                    this.tooltip_max.removeClass('top');
                    this.tooltip_max.addClass('bottom')[0].style.top = 18 + 'px';
                } else {
                    this.tooltip_max.removeClass('bottom');
                    this.tooltip_max.addClass('top')[0].style.top = -30 + 'px';
                }
            }

            if (this.range) {
                this.tooltipInner.text(
                    this.formater(this.value[0]) + this.tooltip_separator + this.formater(this.value[1])
                );
                this.tooltip[0].style[this.stylePos] = this.size * (positionPercentages[0] + (positionPercentages[1] - positionPercentages[0])/2)/100 - (this.orientation === 'vertical' ? this.tooltip.outerHeight()/2 : this.tooltip.outerWidth()/2) +'px';

                this.tooltipInner_min.text(
                    this.formater(this.value[0])
                );
                this.tooltipInner_max.text(
                    this.formater(this.value[1])
                );

                this.tooltip_min[0].style[this.stylePos] = this.size * ( (positionPercentages[0])/100) - (this.orientation === 'vertical' ? this.tooltip_min.outerHeight()/2 : this.tooltip_min.outerWidth()/2) +'px';
                this.tooltip_max[0].style[this.stylePos] = this.size * ( (positionPercentages[1])/100) - (this.orientation === 'vertical' ? this.tooltip_max.outerHeight()/2 : this.tooltip_max.outerWidth()/2) +'px';

            } else {
                this.tooltipInner.text(
                    this.formater(this.value[0])
                );
                this.tooltip[0].style[this.stylePos] = this.size * positionPercentages[0]/100 - (this.orientation === 'vertical' ? this.tooltip.outerHeight()/2 : this.tooltip.outerWidth()/2) +'px';
            }
        },

        mousedown: function(ev) {
            if(!this.isEnabled()) {
                return false;
            }
            // Touch: Get the original event:
            if (this.touchCapable && ev.type === 'touchstart') {
                ev = ev.originalEvent;
            }

            this.triggerFocusOnHandle();

            this.offset = this.picker.offset();
            this.size = this.picker[0][this.sizePos];

            var percentage = this.getPercentage(ev);

            if (this.range) {
                var diff1 = Math.abs(this.percentage[0] - percentage);
                var diff2 = Math.abs(this.percentage[1] - percentage);
                this.dragged = (diff1 < diff2) ? 0 : 1;
            } else {
                this.dragged = 0;
            }

            this.percentage[this.dragged] = this.reversed ? 100 - percentage : percentage;
            this.layout();

            if (this.touchCapable) {
                // Touch: Bind touch events:
                $(document).on({
                    touchmove: $.proxy(this.mousemove, this),
                    touchend: $.proxy(this.mouseup, this)
                });
            }
            // Bind mouse events:
            $(document).on({
                mousemove: $.proxy(this.mousemove, this),
                mouseup: $.proxy(this.mouseup, this)
            });

            this.inDrag = true;
            var val = this.calculateValue();
            this.element.trigger({
                    type: 'slideStart',
                    value: val
                })
                .data('value', val)
                .prop('value', val);
            this.setValue(val);
            return true;
        },

        triggerFocusOnHandle: function(handleIdx) {
            if(handleIdx === 0) {
                this.handle1.focus();
            }
            if(handleIdx === 1) {
                this.handle2.focus();
            }
        },

        keydown: function(handleIdx, ev) {
            if(!this.isEnabled()) {
                return false;
            }

            var dir;
            switch (ev.which) {
                case 37: // left
                case 40: // down
                    dir = -1;
                    break;
                case 39: // right
                case 38: // up
                    dir = 1;
                    break;
            }
            if (!dir) {
                return;
            }

            var oneStepValuePercentageChange = dir * this.percentage[2];
            var percentage = this.percentage[handleIdx] + oneStepValuePercentageChange;

            if (percentage > 100) {
                percentage = 100;
            } else if (percentage < 0) {
                percentage = 0;
            }

            this.dragged = handleIdx;
            this.adjustPercentageForRangeSliders(percentage);
            this.percentage[this.dragged] = percentage;
            this.layout();

            var val = this.calculateValue();
            
            this.element.trigger({
                    type: 'slideStart',
                    value: val
                })
                .data('value', val)
                .prop('value', val);

            this.slide(val);

            this.element
                .trigger({
                    type: 'slideStop',
                    value: val
                })
                .data('value', val)
                .prop('value', val);
            return false;
        },

        mousemove: function(ev) {
            if(!this.isEnabled()) {
                return false;
            }
            // Touch: Get the original event:
            if (this.touchCapable && ev.type === 'touchmove') {
                ev = ev.originalEvent;
            }

            var percentage = this.getPercentage(ev);
            this.adjustPercentageForRangeSliders(percentage);
            this.percentage[this.dragged] = this.reversed ? 100 - percentage : percentage;
            this.layout();

            var val = this.calculateValue();
            this.slide(val);

            return false;
        },
        slide: function(val) {
            this.setValue(val);

            var slideEventValue = this.range ? this.value : this.value[0];
            this.element
                .trigger({
                    'type': 'slide',
                    'value': slideEventValue
                })
                .data('value', this.value)
                .prop('value', this.value);
        },
        adjustPercentageForRangeSliders: function(percentage) {
            if (this.range) {
                if (this.dragged === 0 && this.percentage[1] < percentage) {
                    this.percentage[0] = this.percentage[1];
                    this.dragged = 1;
                } else if (this.dragged === 1 && this.percentage[0] > percentage) {
                    this.percentage[1] = this.percentage[0];
                    this.dragged = 0;
                }
            }
        },

        mouseup: function() {
            if(!this.isEnabled()) {
                return false;
            }
            if (this.touchCapable) {
                // Touch: Unbind touch event handlers:
                $(document).off({
                    touchmove: this.mousemove,
                    touchend: this.mouseup
                });
            }
            // Unbind mouse event handlers:
            $(document).off({
                mousemove: this.mousemove,
                mouseup: this.mouseup
            });

            this.inDrag = false;
            if (this.over === false) {
                this.hideTooltip();
            }
            var val = this.calculateValue();
            this.layout();
            this.element
                .data('value', val)
                .prop('value', val)
                .trigger({
                    type: 'slideStop',
                    value: val
                });
            return false;
        },

        calculateValue: function() {
            var val;
            if (this.range) {
                val = [this.min,this.max];
                if (this.percentage[0] !== 0){
                    val[0] = (Math.max(this.min, this.min + Math.round((this.diff * this.percentage[0]/100)/this.step)*this.step));
                    val[0] = this.applyPrecision(val[0]);
                }
                if (this.percentage[1] !== 100){
                    val[1] = (Math.min(this.max, this.min + Math.round((this.diff * this.percentage[1]/100)/this.step)*this.step));
                    val[1] = this.applyPrecision(val[1]);
                }
                this.value = val;
            } else {
                val = (this.min + Math.round((this.diff * this.percentage[0]/100)/this.step)*this.step);
                if (val < this.min) {
                    val = this.min;
                }
                else if (val > this.max) {
                    val = this.max;
                }
                val = parseFloat(val);
                val = this.applyPrecision(val);
                this.value = [val, this.value[1]];
            }
            return val;
        },
        applyPrecision: function(val) {
            var precision = this.precision || this.getNumDigitsAfterDecimalPlace(this.step);
            return this.applyToFixedAndParseFloat(val, precision);
        },
        /*
            Credits to Mike Samuel for the following method!
            Source: http://stackoverflow.com/questions/10454518/javascript-how-to-retrieve-the-number-of-decimals-of-a-string-number
        */
        getNumDigitsAfterDecimalPlace: function(num) {
            var match = (''+num).match(/(?:\.(\d+))?(?:[eE]([+-]?\d+))?$/);
            if (!match) { return 0; }
            return Math.max(0, (match[1] ? match[1].length : 0) - (match[2] ? +match[2] : 0));
        },

        applyToFixedAndParseFloat: function(num, toFixedInput) {
            var truncatedNum = num.toFixed(toFixedInput);
            return parseFloat(truncatedNum);
        },

        getPercentage: function(ev) {
            if (this.touchCapable && (ev.type === 'touchstart' || ev.type === 'touchmove')) {
                ev = ev.touches[0];
            }
            var percentage = (ev[this.mousePos] - this.offset[this.stylePos])*100/this.size;
            percentage = Math.round(percentage/this.percentage[2])*this.percentage[2];
            return Math.max(0, Math.min(100, percentage));
        },

        getValue: function() {
            if (this.range) {
                return this.value;
            }
            return this.value[0];
        },

        setValue: function(val) {
            if (!val) {
                val = 0;
            }
            this.value = this.validateInputValue(val);

            if (this.range) {
                this.value[0] = this.applyPrecision(this.value[0]);
                this.value[1] = this.applyPrecision(this.value[1]); 

                this.value[0] = Math.max(this.min, Math.min(this.max, this.value[0]));
                this.value[1] = Math.max(this.min, Math.min(this.max, this.value[1]));
            } else {
                this.value = this.applyPrecision(this.value);
                this.value = [ Math.max(this.min, Math.min(this.max, this.value))];
                this.handle2.addClass('hide');
                if (this.selection === 'after') {
                    this.value[1] = this.max;
                } else {
                    this.value[1] = this.min;
                }
            }

            this.diff = this.max - this.min;
            if (this.diff > 0) {
                this.percentage = [
                    (this.value[0] - this.min) * 100 / this.diff,
                    (this.value[1] - this.min) * 100 / this.diff,
                    this.step * 100 / this.diff
                ];
            } else {
                this.percentage = [0, 0, 100];
            }

            this.layout();
        },

        validateInputValue : function(val) {
            if(typeof val === 'number') {
                return val;
            } else if(val instanceof Array) {
                $.each(val, function(i, input) { if (typeof input !== 'number') { throw new Error( ErrorMsgs.formatInvalidInputErrorMsg(input) ); }});
                return val;
            } else {
                throw new Error( ErrorMsgs.formatInvalidInputErrorMsg(val) );
            }
        },

        destroy: function(){
            this.handle1.off();
            this.handle2.off();
            this.element.off().show().insertBefore(this.picker);
            this.picker.off().remove();
            $(this.element).removeData('slider');
        },

        disable: function() {
            this.enabled = false;
            this.handle1.removeAttr("tabindex");
            this.handle2.removeAttr("tabindex");
            this.picker.addClass('slider-disabled');
            this.element.trigger('slideDisabled');
        },

        enable: function() {
            this.enabled = true;
            this.handle1.attr("tabindex", 0);
            this.handle2.attr("tabindex", 0);
            this.picker.removeClass('slider-disabled');
            this.element.trigger('slideEnabled');
        },

        toggle: function() {
            if(this.enabled) {
                this.disable();
            } else {
                this.enable();
            }
        },

        isEnabled: function() {
            return this.enabled;
        },

        setAttribute: function(attribute, value) {
            this[attribute] = value;
        },

        getAttribute: function(attribute) {
            return this[attribute];
        }

    };

    var publicMethods = {
        getValue : Slider.prototype.getValue,
        setValue : Slider.prototype.setValue,
        setAttribute : Slider.prototype.setAttribute,
        getAttribute : Slider.prototype.getAttribute,
        destroy : Slider.prototype.destroy,
        disable : Slider.prototype.disable,
        enable : Slider.prototype.enable,
        toggle : Slider.prototype.toggle,
        isEnabled: Slider.prototype.isEnabled
    };

    $.fn.slider = function (option) {
        if (typeof option === 'string' && option !== 'refresh') {
            var args = Array.prototype.slice.call(arguments, 1);
            return invokePublicMethod.call(this, option, args);
        } else {
            return createNewSliderInstance.call(this, option);
        }
    };

    function invokePublicMethod(methodName, args) {
        if(publicMethods[methodName]) {
            var sliderObject = retrieveSliderObjectFromElement(this);
            var result = publicMethods[methodName].apply(sliderObject, args);

            if (typeof result === "undefined") {
                return $(this);
            } else {
                return result;
            }
        } else {
            throw new Error("method '" + methodName + "()' does not exist for slider.");
        }
    }

    function retrieveSliderObjectFromElement(element) {
        var sliderObject = $(element).data('slider');
        if(sliderObject && sliderObject instanceof Slider) {
            return sliderObject;
        } else {
            throw new Error(ErrorMsgs.callingContextNotSliderInstance);
        }
    }

    function createNewSliderInstance(opts) {
        var $this = $(this);
        $this.each(function() {
            var $this = $(this),
                slider = $this.data('slider'),
                options = typeof opts === 'object' && opts;

            // If slider already exists, use its attributes
            // as options so slider refreshes properly
            if (slider && !options) {
                options = {};

                $.each($.fn.slider.defaults, function(key) {
                    options[key] = slider[key];
                });
            }

            $this.data('slider', (new Slider(this, $.extend({}, $.fn.slider.defaults, options))));
        });
        return $this;
    }

    $.fn.slider.defaults = {
        min: 0,
        max: 10,
        step: 1,
        precision: 0,
        orientation: 'horizontal',
        value: 5,
        range: false,
        selection: 'before',
        tooltip: 'show',
        tooltip_separator: ':',
        tooltip_split: false,
        handle: 'round',
        reversed : false,
        enabled: true,
        formater: function(value) {
            return value;
        }
    };

    $.fn.slider.Constructor = Slider;

})( window.jQuery );

/* vim: set noexpandtab tabstop=4 shiftwidth=4 autoindent: */

/* =========================================================
 * bootstrap-datepicker.js 
 * http://www.eyecon.ro/bootstrap-datepicker
 * =========================================================
 * Copyright 2012 Stefan Petre
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 * ========================================================= */
 
!function( $ ) {
    
    // Picker object
    
    var Datepicker = function(element, options){
        this.element = $(element);
        this.format = DPGlobal.parseFormat(options.format||this.element.data('date-format')||'mm/dd/yyyy');
        this.picker = $(DPGlobal.template)
                            .appendTo('body')
                            .on({
                                click: $.proxy(this.click, this)//,
                                //mousedown: $.proxy(this.mousedown, this)
                            });
        this.isInput = this.element.is('input');
        this.component = this.element.is('.date') ? this.element.find('.add-on') : false;
        
        if (this.isInput) {
            this.element.on({
                focus: $.proxy(this.show, this),
                //blur: $.proxy(this.hide, this),
                keyup: $.proxy(this.update, this)
            });
        } else {
            if (this.component){
                this.component.on('click', $.proxy(this.show, this));
            } else {
                this.element.on('click', $.proxy(this.show, this));
            }
        }
    
        this.minViewMode = options.minViewMode||this.element.data('date-minviewmode')||0;
        if (typeof this.minViewMode === 'string') {
            switch (this.minViewMode) {
                case 'months':
                    this.minViewMode = 1;
                    break;
                case 'years':
                    this.minViewMode = 2;
                    break;
                default:
                    this.minViewMode = 0;
                    break;
            }
        }
        this.viewMode = options.viewMode||this.element.data('date-viewmode')||0;
        if (typeof this.viewMode === 'string') {
            switch (this.viewMode) {
                case 'months':
                    this.viewMode = 1;
                    break;
                case 'years':
                    this.viewMode = 2;
                    break;
                default:
                    this.viewMode = 0;
                    break;
            }
        }
        this.startViewMode = this.viewMode;
        this.weekStart = options.weekStart||this.element.data('date-weekstart')||0;
        this.weekEnd = this.weekStart === 0 ? 6 : this.weekStart - 1;
        this.onRender = options.onRender;
        this.fillDow();
        this.fillMonths();
        this.update();
        this.showMode();
    };
    
    Datepicker.prototype = {
        constructor: Datepicker,
        
        show: function(e) {
            this.picker.show();
            this.height = this.component ? this.component.outerHeight() : this.element.outerHeight();
            this.place();
            $(window).on('resize', $.proxy(this.place, this));
            if (e ) {
                e.stopPropagation();
                e.preventDefault();
            }
            if (!this.isInput) {
            }
            var that = this;
            $(document).on('mousedown', function(ev){
                if ($(ev.target).closest('.datepicker').length == 0) {
                    that.hide();
                }
            });
            this.element.trigger({
                type: 'show',
                date: this.date
            });
        },
        
        hide: function(){
            this.picker.hide();
            $(window).off('resize', this.place);
            this.viewMode = this.startViewMode;
            this.showMode();
            if (!this.isInput) {
                $(document).off('mousedown', this.hide);
            }
            //this.set();
            this.element.trigger({
                type: 'hide',
                date: this.date
            });
        },
        
        set: function() {
            var formated = DPGlobal.formatDate(this.date, this.format);
            if (!this.isInput) {
                if (this.component){
                    this.element.find('input').prop('value', formated);
                }
                this.element.data('date', formated);
            } else {
                this.element.prop('value', formated);
            }
        },
        
        setValue: function(newDate) {
            if (typeof newDate === 'string') {
                this.date = DPGlobal.parseDate(newDate, this.format);
            } else {
                this.date = new Date(newDate);
            }
            this.set();
            this.viewDate = new Date(this.date.getFullYear(), this.date.getMonth(), 1, 0, 0, 0, 0);
            this.fill();
        },
        
        place: function(){
            var offset = this.component ? this.component.offset() : this.element.offset();
            this.picker.css({
                top: offset.top + this.height,
                left: offset.left
            });
        },
        
        update: function(newDate){
            this.date = DPGlobal.parseDate(
                typeof newDate === 'string' ? newDate : (this.isInput ? this.element.prop('value') : this.element.data('date')),
                this.format
            );
            this.viewDate = new Date(this.date.getFullYear(), this.date.getMonth(), 1, 0, 0, 0, 0);
            this.fill();
        },
        
        fillDow: function(){
            var dowCnt = this.weekStart;
            var html = '<tr>';
            while (dowCnt < this.weekStart + 7) {
                html += '<th class="dow">'+DPGlobal.dates.daysMin[(dowCnt++)%7]+'</th>';
            }
            html += '</tr>';
            this.picker.find('.datepicker-days thead').append(html);
        },
        
        fillMonths: function(){
            var html = '';
            var i = 0
            while (i < 12) {
                html += '<span class="month">'+DPGlobal.dates.monthsShort[i++]+'</span>';
            }
            this.picker.find('.datepicker-months td').append(html);
        },
        
        fill: function() {
            var d = new Date(this.viewDate),
                year = d.getFullYear(),
                month = d.getMonth(),
                currentDate = this.date.valueOf();
            this.picker.find('.datepicker-days th:eq(1)')
                        .text(DPGlobal.dates.months[month]+' '+year);
            var prevMonth = new Date(year, month-1, 28,0,0,0,0),
                day = DPGlobal.getDaysInMonth(prevMonth.getFullYear(), prevMonth.getMonth());
            prevMonth.setDate(day);
            prevMonth.setDate(day - (prevMonth.getDay() - this.weekStart + 7)%7);
            var nextMonth = new Date(prevMonth);
            nextMonth.setDate(nextMonth.getDate() + 42);
            nextMonth = nextMonth.valueOf();
            var html = [];
            var clsName,
                prevY,
                prevM;
            while(prevMonth.valueOf() < nextMonth) {
                if (prevMonth.getDay() === this.weekStart) {
                    html.push('<tr>');
                }
                clsName = this.onRender(prevMonth);
                prevY = prevMonth.getFullYear();
                prevM = prevMonth.getMonth();
                if ((prevM < month &&  prevY === year) ||  prevY < year) {
                    clsName += ' old';
                } else if ((prevM > month && prevY === year) || prevY > year) {
                    clsName += ' new';
                }
                if (prevMonth.valueOf() === currentDate) {
                    clsName += ' active';
                }
                html.push('<td class="day '+clsName+'">'+prevMonth.getDate() + '</td>');
                if (prevMonth.getDay() === this.weekEnd) {
                    html.push('</tr>');
                }
                prevMonth.setDate(prevMonth.getDate()+1);
            }
            this.picker.find('.datepicker-days tbody').empty().append(html.join(''));
            var currentYear = this.date.getFullYear();
            
            var months = this.picker.find('.datepicker-months')
                        .find('th:eq(1)')
                            .text(year)
                            .end()
                        .find('span').removeClass('active');
            if (currentYear === year) {
                months.eq(this.date.getMonth()).addClass('active');
            }
            
            html = '';
            year = parseInt(year/10, 10) * 10;
            var yearCont = this.picker.find('.datepicker-years')
                                .find('th:eq(1)')
                                    .text(year + '-' + (year + 9))
                                    .end()
                                .find('td');
            year -= 1;
            for (var i = -1; i < 11; i++) {
                html += '<span class="year'+(i === -1 || i === 10 ? ' old' : '')+(currentYear === year ? ' active' : '')+'">'+year+'</span>';
                year += 1;
            }
            yearCont.html(html);
        },
        
        click: function(e) {
            e.stopPropagation();
            e.preventDefault();
            var target = $(e.target).closest('span, td, th');
            if (target.length === 1) {
                switch(target[0].nodeName.toLowerCase()) {
                    case 'th':
                        switch(target[0].className) {
                            case 'switch':
                                this.showMode(1);
                                break;
                            case 'prev':
                            case 'next':
                                this.viewDate['set'+DPGlobal.modes[this.viewMode].navFnc].call(
                                    this.viewDate,
                                    this.viewDate['get'+DPGlobal.modes[this.viewMode].navFnc].call(this.viewDate) + 
                                    DPGlobal.modes[this.viewMode].navStep * (target[0].className === 'prev' ? -1 : 1)
                                );
                                this.fill();
                                this.set();
                                break;
                        }
                        break;
                    case 'span':
                        if (target.is('.month')) {
                            var month = target.parent().find('span').index(target);
                            this.viewDate.setMonth(month);
                        } else {
                            var year = parseInt(target.text(), 10)||0;
                            this.viewDate.setFullYear(year);
                        }
                        if (this.viewMode !== 0) {
                            this.date = new Date(this.viewDate);
                            this.element.trigger({
                                type: 'changeDate',
                                date: this.date,
                                viewMode: DPGlobal.modes[this.viewMode].clsName
                            });
                        }
                        this.showMode(-1);
                        this.fill();
                        this.set();
                        break;
                    case 'td':
                        if (target.is('.day') && !target.is('.disabled')){
                            var day = parseInt(target.text(), 10)||1;
                            var month = this.viewDate.getMonth();
                            if (target.is('.old')) {
                                month -= 1;
                            } else if (target.is('.new')) {
                                month += 1;
                            }
                            var year = this.viewDate.getFullYear();
                            this.date = new Date(year, month, day,0,0,0,0);
                            this.viewDate = new Date(year, month, Math.min(28, day),0,0,0,0);
                            this.fill();
                            this.set();
                            this.element.trigger({
                                type: 'changeDate',
                                date: this.date,
                                viewMode: DPGlobal.modes[this.viewMode].clsName
                            });
                        }
                        break;
                }
            }
        },
        
        mousedown: function(e){
            e.stopPropagation();
            e.preventDefault();
        },
        
        showMode: function(dir) {
            if (dir) {
                this.viewMode = Math.max(this.minViewMode, Math.min(2, this.viewMode + dir));
            }
            this.picker.find('>div').hide().filter('.datepicker-'+DPGlobal.modes[this.viewMode].clsName).show();
        }
    };
    
    $.fn.datepicker = function ( option, val ) {
        return this.each(function () {
            var $this = $(this),
                data = $this.data('datepicker'),
                options = typeof option === 'object' && option;
            if (!data) {
                $this.data('datepicker', (data = new Datepicker(this, $.extend({}, $.fn.datepicker.defaults,options))));
            }
            if (typeof option === 'string') data[option](val);
        });
    };

    $.fn.datepicker.defaults = {
        onRender: function(date) {
            return '';
        }
    };
    $.fn.datepicker.Constructor = Datepicker;
    
    var DPGlobal = {
        modes: [
            {
                clsName: 'days',
                navFnc: 'Month',
                navStep: 1
            },
            {
                clsName: 'months',
                navFnc: 'FullYear',
                navStep: 1
            },
            {
                clsName: 'years',
                navFnc: 'FullYear',
                navStep: 10
        }],
        dates:{
            days: ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"],
            daysShort: ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"],
            daysMin: ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"],
            months: ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"],
            monthsShort: ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        },
        isLeapYear: function (year) {
            return (((year % 4 === 0) && (year % 100 !== 0)) || (year % 400 === 0))
        },
        getDaysInMonth: function (year, month) {
            return [31, (DPGlobal.isLeapYear(year) ? 29 : 28), 31, 30, 31, 30, 31, 31, 30, 31, 30, 31][month]
        },
        parseFormat: function(format){
            var separator = format.match(/[.\/\-\s].*?/),
                parts = format.split(/\W+/);
            if (!separator || !parts || parts.length === 0){
                throw new Error("Invalid date format.");
            }
            return {separator: separator, parts: parts};
        },
        parseDate: function(date, format) {
            var parts = date.split(format.separator),
                date = new Date(),
                val;
            date.setHours(0);
            date.setMinutes(0);
            date.setSeconds(0);
            date.setMilliseconds(0);
            if (parts.length === format.parts.length) {
                var year = date.getFullYear(), day = date.getDate(), month = date.getMonth();
                for (var i=0, cnt = format.parts.length; i < cnt; i++) {
                    val = parseInt(parts[i], 10)||1;
                    switch(format.parts[i]) {
                        case 'dd':
                        case 'd':
                            day = val;
                            date.setDate(val);
                            break;
                        case 'mm':
                        case 'm':
                            month = val - 1;
                            date.setMonth(val - 1);
                            break;
                        case 'yy':
                            year = 2000 + val;
                            date.setFullYear(2000 + val);
                            break;
                        case 'yyyy':
                            year = val;
                            date.setFullYear(val);
                            break;
                    }
                }
                date = new Date(year, month, day, 0 ,0 ,0);
            }
            return date;
        },
        formatDate: function(date, format){
            var val = {
                d: date.getDate(),
                m: date.getMonth() + 1,
                yy: date.getFullYear().toString().substring(2),
                yyyy: date.getFullYear()
            };
            val.dd = (val.d < 10 ? '0' : '') + val.d;
            val.mm = (val.m < 10 ? '0' : '') + val.m;
            var date = [];
            for (var i=0, cnt = format.parts.length; i < cnt; i++) {
                date.push(val[format.parts[i]]);
            }
            return date.join(format.separator);
        },
        headTemplate: '<thead>'+
                            '<tr>'+
                                '<th class="prev">&lsaquo;</th>'+
                                '<th colspan="5" class="switch"></th>'+
                                '<th class="next">&rsaquo;</th>'+
                            '</tr>'+
                        '</thead>',
        contTemplate: '<tbody><tr><td colspan="7"></td></tr></tbody>'
    };
    DPGlobal.template = '<div class="datepicker dropdown-menu">'+
                            '<div class="datepicker-days">'+
                                '<table class=" table-condensed">'+
                                    DPGlobal.headTemplate+
                                    '<tbody></tbody>'+
                                '</table>'+
                            '</div>'+
                            '<div class="datepicker-months">'+
                                '<table class="table-condensed">'+
                                    DPGlobal.headTemplate+
                                    DPGlobal.contTemplate+
                                '</table>'+
                            '</div>'+
                            '<div class="datepicker-years">'+
                                '<table class="table-condensed">'+
                                    DPGlobal.headTemplate+
                                    DPGlobal.contTemplate+
                                '</table>'+
                            '</div>'+
                        '</div>';

}( window.jQuery );
