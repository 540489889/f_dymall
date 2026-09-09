import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import '../utils/index.dart';

class ImageViewer extends StatefulWidget {
  const ImageViewer({
   super.key,
    this.images,
   this.index = 0,
  });

 final List? images; // 预览图列表
  final int index; // 当前预览图索引
  @override
  State<ImageViewer> createState() => _ImageViewerState();
}

class _ImageViewerState extends State<ImageViewer> {
  int currentIndex = 0;

  @override
  void initState() {
    super.initState();
    currentIndex = widget.index;
  }

  @override
  Widget build(BuildContext context) {
    var imgCount = widget.images?.length;

    return Scaffold(
      body: Stack(
      children: [
      Positioned(
        top: 0,
        left: 0,
        bottom: 0,
        right: 0,
        child: GestureDetector(
        child: imgCount == 1 ? PhotoView(
          imageProvider: Utils.isUrl(widget.images![0]) ? NetworkImage(widget.images![0]) : AssetImage(widget.images![0]),
        backgroundDecoration: const BoxDecoration(
          color: Colors.black,
        ),
        minScale: PhotoViewComputedScale.contained,
        maxScale: PhotoViewComputedScale.covered * 2,
        heroAttributes: PhotoViewHeroAttributes(tag: widget.images![0]),
        enableRotation: true,
      )
      :
      PhotoViewGallery.builder(
        itemCount: widget.images?.length,
        builder: (context, index) {
        return PhotoViewGalleryPageOptions(
          imageProvider: Utils.isUrl(widget.images![index]) ? NetworkImage(widget.images![index]) : AssetImage(widget.images![index]),
          minScale: PhotoViewComputedScale.contained,
          maxScale: PhotoViewComputedScale.covered * 2,
          heroAttributes: PhotoViewHeroAttributes(tag: widget.images![index]),
        );
      },
      scrollPhysics: const BouncingScrollPhysics(),
      backgroundDecoration: const BoxDecoration(
        color: Colors.black,
      ),
      pageController: PageController(initialPage: widget.index),
        enableRotation: true,
        onPageChanged: (index) {
          setState(() {
            currentIndex = index;
            });
          },
        ),
        onTap: () {
          Get.back();
          },
        ),
      ),
      // 图片索引index
      Positioned(
        top: MediaQuery.of(context).padding.top + 15,
        width: MediaQuery.of(context).size.width,
        child: Center(
          child: Visibility(
            visible: imgCount! > 1 ? true : false,
            child: Text('${currentIndex+1} / ${widget.images?.length}', style: const TextStyle(color: Colors.white, fontSize: 16, fontFamily: 'arial'),),
          )
        ),
      ),
      ],
    ),
  );
  }
}
