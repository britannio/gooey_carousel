import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'side.dart';

import 'gooey_edge.dart';
import 'gooey_edge_clipper.dart';

class GooeyCarousel extends StatefulWidget {
  GooeyCarousel({
    Key key,
    @required this.children,
    this.onIndexUpdate,
    this.loop = false,
  }) : super(key: key);

  final List<Widget> children;
  final void Function(int index) onIndexUpdate;
  final bool loop;

  @override
  GooeyCarouselState createState() => GooeyCarouselState();
}

class GooeyCarouselState extends State<GooeyCarousel>
    with SingleTickerProviderStateMixin {
  int _index = 0; // index of the base (bottom) child
  Offset _dragOffset; // starting offset of the drag
  double _dragDirection; // +1 when dragging left to right, -1 for right to left

  bool _dragCompleted; // has the drag successfully resulted in a swipe
  bool get dragCompleted => _dragCompleted;
  set dragCompleted(bool value) {
    _dragCompleted = value;
    if (value && widget.onIndexUpdate != null) {
      widget.onIndexUpdate(_dragIndex);
    }
  }

  int _dragIndex; // index of the top child

  GooeyEdge _edge;
  Ticker _ticker;
  GlobalKey _key = GlobalKey();

  @override
  void initState() {
    _edge = GooeyEdge(count: 25);
    _ticker = createTicker(_tick)..start();
    super.initState();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _tick(Duration duration) {
    _edge.tick(duration);
    setState(() {});
  }

  Size _getSize() {
    final RenderBox box = _key.currentContext.findRenderObject();
    return box.size;
  }

  void _handlePanDown(DragDownDetails details, Size size) {
    if (_dragIndex != null && dragCompleted) {
      _index = _dragIndex;
    }
    _dragIndex = null;
    _dragOffset = details.localPosition;
    dragCompleted = false;
    _dragDirection = 0;

    _edge.farEdgeTension = 0.0;
    _edge.edgeTension = 0.01;
    _edge.reset();
  }

  void _handlePanUpdate(DragUpdateDetails details, Size size) {
    double dx = details.globalPosition.dx - _dragOffset.dx;

    if (!_isSwipeActive(dx)) {
      return;
    }
    if (_isSwipeComplete(dx, size.width)) {
      return;
    }

    if (_dragDirection == -1) {
      dx = size.width + dx;
    }
    _edge.applyTouchOffset(Offset(dx, details.localPosition.dy), size);
  }

  void _handlePanEnd(DragEndDetails details, Size size) {
    _edge.applyTouchOffset();
  }

  bool _isSwipeActive(double dx) {
    // Veto swiping if going in a loop is disabled
    if (!widget.loop) {
      final bool goingBackwards = dx > 0;
      final bool goingForwards = dx < 0;

      final bool onFirstPage = _index == 0;
      final bool onLastPage = _index + 1 == widget.children.length;
      // Attempting to swipe right on the first page
      if (goingBackwards && onFirstPage) return false;
      // Attempting to swipe left on the last page
      if (goingForwards && onLastPage) return false;
    }

    // check if a swipe is just starting:
    if (_dragDirection == 0.0 && dx.abs() > 20.0) {
      _dragDirection = dx.sign;
      _edge.side = _dragDirection == 1.0 ? Side.left : Side.right;
      setState(() {
        _dragIndex = _index - _dragDirection.toInt();
      });
    }
    return _dragDirection != 0.0;
  }

  bool _isSwipeComplete(double dx, double width) {
    if (_dragDirection == 0.0) {
      return false;
    } // haven't started
    if (dragCompleted) {
      return true;
    } // already done

    // check if swipe is just completed:
    double availW = _dragOffset.dx;
    if (_dragDirection == 1) {
      availW = width - availW;
    }
    double ratio = dx * _dragDirection / availW;

    if (ratio > 0.8 && availW / width > 0.5) {
      dragCompleted = true;
      _edge.farEdgeTension = 0.01;
      _edge.edgeTension = 0.0;
      _edge.applyTouchOffset();
    }
    return dragCompleted;
  }

  @override
  Widget build(BuildContext context) {
    int length = widget.children.length;

    return GestureDetector(
      key: _key,
      onPanDown: (details) => _handlePanDown(details, _getSize()),
      onPanUpdate: (details) => _handlePanUpdate(details, _getSize()),
      onPanEnd: (details) => _handlePanEnd(details, _getSize()),
      child: Stack(
        children: <Widget>[
          widget.children[_index % length],
          _dragIndex == null
              ? SizedBox()
              : ClipPath(
                  child: widget.children[_dragIndex % length],
                  clipBehavior: Clip.antiAlias,
                  clipper: GooeyEdgeClipper(_edge, margin: 10.0),
                ),
        ],
      ),
    );
  }
}
