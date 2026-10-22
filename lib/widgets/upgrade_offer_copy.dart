import 'package:flutter/material.dart';
import 'package:regun/utils/constants.dart';

/// Expanding this secondary action never selects the surrounding offer.
class UpgradeOfferCopy extends StatefulWidget {
  const UpgradeOfferCopy({
    super.key,
    required this.description,
    required this.summary,
    required this.details,
    this.initiallyExpanded = false,
  });

  final String description, summary, details;
  final bool initiallyExpanded;

  @override
  State<UpgradeOfferCopy> createState() => _UpgradeOfferCopyState();
}

class _UpgradeOfferCopyState extends State<UpgradeOfferCopy> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        widget.description,
        style: const TextStyle(
          fontFamily: FontFam.orbitron,
          fontSize: 12,
          height: 1.4,
          color: Color(0xffB2A8B4),
        ),
      ),
      if ((_expanded ? widget.details : widget.summary).isNotEmpty) ...[
        const SizedBox(height: 8),
        Text(
          _expanded ? widget.details : widget.summary,
          style: const TextStyle(
            fontFamily: FontFam.orbitron,
            fontSize: 12,
            height: 1.4,
            color: Color(0xffE5DDD1),
          ),
        ),
      ],
      if (widget.details.isNotEmpty && widget.details != widget.summary)
        TextButton(
          onPressed: () => setState(() => _expanded = !_expanded),
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xffE1BA78),
            minimumSize: const Size(48, 48),
            padding: EdgeInsets.zero,
            alignment: Alignment.centerLeft,
            shape: const RoundedRectangleBorder(),
            textStyle: const TextStyle(
              fontFamily: FontFam.orbitron,
              fontSize: 10,
            ),
          ),
          child: Text(_expanded ? 'LESS DETAIL' : 'DETAILS'),
        ),
    ],
  );
}
