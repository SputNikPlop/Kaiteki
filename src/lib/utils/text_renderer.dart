import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:html/dom.dart';
import 'package:kaiteki/api/model/mastodon/emoji.dart';
import 'package:kaiteki/utils/text_buffer.dart';
import 'package:kaiteki/utils/utils.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:html/parser.dart' show parseFragment;
import 'package:html/dom.dart' as dom;

class TextRenderer {
  Iterable<MastodonEmoji> emojis;

  TextStyle textStyle;
  TextStyle linkTextStyle;

  static const String emojiChar = ":";
  static const String linkTag = "a";

  bool get _supportEmoji => emojis != null && emojis.length != 0;
  
  TextRenderer({this.emojis, this.textStyle, this.linkTextStyle});

  InlineSpan render(String text) => renderNode(parseFragment(text));

  InlineSpan renderSpecial(String text, {List<InlineSpan> children}) {
    var spans = <InlineSpan>[];
    var buffer = TextBuffer();

    var readingEmoji = false;
    for (var i = 0; i < text.length; i++) {
      var char = text[i];

      switch (char) {
        case emojiChar: {
          if (!_supportEmoji)
            continue;

          if (readingEmoji) {
            var emojiName = buffer.text;
            var emojiFound = emojis.any((e) => Utils.compareCaseInsensitive(e.shortcode, emojiName));

            if (emojiFound) {
              var emoji = emojis.firstWhere((e) => Utils.compareCaseInsensitive(e.shortcode, emojiName));

              buffer.clear();

              // FIXME: fix it or I will make you not-cute >:(
              var emojiSpan = WidgetSpan(
                child: Image.network(
                  emoji.staticUrl,
                  width: 32,
                  height: 32,
                ),
              );

              spans.add(emojiSpan);

              readingEmoji = false;
            } else {
              // nothing found, so we restore the stolen colon and add a normal text span.
              buffer.prepend(emojiChar);
              spans.add(plain(buffer));
              readingEmoji = true;
            }
          } else {
            spans.add(plain(buffer));
            readingEmoji = true;
          }

          break;
        }
        default: {
          buffer.append(char);
          break;
        }
      }
    }

    if (buffer.text.isNotEmpty)
      spans.add(plain(buffer));

    return TextSpan(children: spans..addAll(children));
  }

  InlineSpan renderNode(Node node) {
    InlineSpan resultingSpan;

    var renderedSubNodes = node.nodes
      .map<InlineSpan>((n) => renderNode(n))
      .toList(growable: false);

    if (node is dom.Element) {
      if (node.localName == linkTag) {
        var recognizer = new TapGestureRecognizer();
        recognizer.onTap = () {
          if (node.classes.contains("mention")) {
            print("user!");
            print(node.classes.join(";"));
            return;
          }

          var linkTarget = node.attributes["href"];
          launch(linkTarget);
        };

        resultingSpan = TextSpan(
          text: node.text,
          recognizer: recognizer,
          style: textStyle.copyWith(
            decoration: TextDecoration.underline,
            color: Colors.blue
          )
        );
      } else {
        print(node.localName);
      }
    } else if (node is dom.Text) {
      dom.Text textElement = node;
      resultingSpan = renderSpecial(
        textElement.text,
        children: renderedSubNodes,
      );
    }

    if (resultingSpan == null) {
      resultingSpan = TextSpan(
        children: renderedSubNodes
      );
    }

    return resultingSpan;
  }

  TextSpan plain(TextBuffer buffer) => TextSpan(
    style: textStyle,
    text: buffer.cut()
  );
}



