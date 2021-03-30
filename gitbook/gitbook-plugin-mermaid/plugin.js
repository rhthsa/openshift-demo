require(['gitbook', 'jquery'], function(gitbook, $) {
    gitbook.events.bind('page.change', function() {
        $('code.lang-mermaid').each(function(index, element) {
            var $element = $(element);
            var code = $element.text();

            var wrapper = $('<div class="mermaid">' + code + '</div>');
            $element.parent().replaceWith(wrapper);
        });
    });
});
