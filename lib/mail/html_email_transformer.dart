import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart';

class HtmlEmailTransformer {
  /// Hauptmethode: vollständiges HTML → zitierfähiges Fragment
  String transformHtml(String originalHtml, String prefixHeader, bool isForward) {
    final document = html_parser.parse(originalHtml);

    final body = document.body;
    if (body == null) {
      return '';
    }

    _removeDangerousNodes(body);

    _inlineOrRemoveStyles(document, body);

    final cleanedFragment = body.innerHtml.trim();

    return isForward
        ? _wrapAsForwardQuote(cleanedFragment, prefixHeader)
        : _wrapAsReplyQuote(cleanedFragment, prefixHeader);
  }

  String sanitizeHtml(String originalHtml) {
    final document = html_parser.parse(originalHtml);

    final body = document.body;
    if (body == null) {
      return '';
    }

    _removeDangerousNodes(body);

    _inlineOrRemoveStyles(document, body);

    final cleanedFragment = body.innerHtml.trim();
    //return cleanedFragment;
    return '''
  <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "https://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd”>
  <html xmlns=“https://www.w3.org/1999/xhtml">
  <head>
    <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
    <meta http-equiv="X-UA-Compatible" content="IE=edge" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  </head>
  <body>
    $cleanedFragment
  </body>
  </html>
'''
        .trim();
  }

  // ------------------------------------------------------------

  void _removeDangerousNodes(Element root) {
    final forbiddenTags = {
      'script',
      'iframe',
      'object',
      'embed',
      'meta',
      'link',
      'base',
      'noscript',
    };

    root.querySelectorAll('*').toList().forEach((element) {
      if (forbiddenTags.contains(element.localName)) {
        element.remove();
        return;
      }

      // Event-Handler entfernen (onclick etc.)
      element.attributes.removeWhere(
        (key, _) => (key as String).toLowerCase().startsWith('on'),
      );
    });
  }

  // ------------------------------------------------------------

  void _inlineOrRemoveStyles(Document document, Element body) {
    // Thunderbird entfernt <style> meist vollständig
    final styleElements = document.head?.querySelectorAll('style') ?? [];

    for (final style in styleElements) {
      style.remove();
    }

    // Optional: CSS-Attribute einschränken
    body.querySelectorAll('[style]').forEach((element) {
      final sanitized = _sanitizeInlineStyle(element.attributes['style']!);
      if (sanitized.isEmpty) {
        element.attributes.remove('style');
      } else {
        element.attributes['style'] = sanitized;
      }
    });
  }

  // ------------------------------------------------------------

  String _sanitizeInlineStyle(String style) {
    final allowedProperties = {
      'color',
      'background-color',
      'font-weight',
      'font-style',
      'text-decoration',
      'font-size',
      'font-family',
      'margin',
      'padding',
      'border',
      'text-align',
    };

    final buffer = StringBuffer();

    for (final rule in style.split(';')) {
      final parts = rule.split(':');
      if (parts.length != 2) continue;

      final property = parts[0].trim().toLowerCase();
      final value = parts[1].trim();

      if (allowedProperties.contains(property)) {
        buffer.write('$property:$value;');
      }
    }

    return buffer.toString();
  }

  // ------------------------------------------------------------

  String _wrapAsForwardQuote(String innerHtml, String prefixHeader) {
    return '''
<div class="forwarded-message">
  <div class="forward-header"
       style="margin:1em 0;color:#555;font-family:monospace">
${prefixHeader.split(
              '\r\n',
            ).join(
              '<br/>\r\n',
            )}       
  </div>
  <div class="forward-body"
       style="margin-left:1em;border-left:2px solid #ccc;padding-left:1em">
    $innerHtml
  </div>
</div>
'''
        .trim();
  }

  String _wrapAsReplyQuote(String innerHtml, String prefixHeader) {
    return '''
  <blockquote class="cite"
              style="margin-left:1em;border-left:2px solid #ccc;padding-left:1em">
  <div class="reply-header"
       style="margin:1em 0;color:#555;font-family:monospace">
${prefixHeader.split(
              '\r\n',
            ).join(
              '<br/>\r\n',
            )}       
  </div>
    $innerHtml
  </blockquote>
'''
        .trim();
  }

  static String combineHtmlEmail(String? msgPart, String? postPart) {
    return '''
  <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "https://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd”>
  <html xmlns=“https://www.w3.org/1999/xhtml">
  <head>
    <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
    <meta http-equiv="X-UA-Compatible" content="IE=edge" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  </head>
  <body>
       <div style='background-color: white; margin-left: 1rem; margin-right: 1rem;' >
          <div>$msgPart</div>
        </div>
        $postPart
  </body>
  </html>
'''
        .trim();
  }
}
