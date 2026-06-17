import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

class SegmentationService {
  /// 使用 K-Means 聚类进行图像分割
  Future<File> segmentImage(File imageFile) async {
    // 读取图像
    final imageData = await imageFile.readAsBytes();
    final image = img.decodeImage(imageData);

    if (image == null) {
      throw Exception('无法解码图像');
    }

    // 调整图像大小以加快处理速度
    final resized = img.copyResize(image, width: 400, height: 400);

    // 执行颜色分割
    final segmented = _kmeansSegmentation(resized, clusters: 5);

    // 保存结果
    final outputPath = '${imageFile.parent.path}/segmented_${DateTime.now().millisecondsSinceEpoch}.png';
    final outputFile = File(outputPath);
    await outputFile.writeAsBytes(img.encodePng(segmented));

    return outputFile;
  }

  /// K-Means 聚类分割算法
  img.Image _kmeansSegmentation(img.Image image, {int clusters = 5}) {
    final width = image.width;
    final height = image.height;
    final pixels = <Color>[];

    // 提取所有像素的 RGB 值
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final pixel = image.getPixelSafe(x, y);
        final r = pixel.toSafeRed().toInt();
        final g = pixel.toSafeGreen().toInt();
        final b = pixel.toSafeBlue().toInt();
        pixels.add(Color(r, g, b));
      }
    }

    // 初始化聚类中心
    final centroids = <Color>[];
    final random = DateTime.now().microsecond;
    for (int i = 0; i < clusters; i++) {
      final idx = (random + i * 12345) % pixels.length;
      centroids.add(pixels[idx]);
    }

    // K-Means 迭代
    const maxIterations = 10;
    for (int iter = 0; iter < maxIterations; iter++) {
      // 分配像素到最近的聚类中心
      final assignments = <int>[];
      for (final pixel in pixels) {
        int bestCluster = 0;
        double bestDistance = double.infinity;

        for (int c = 0; c < centroids.length; c++) {
          final distance = pixel.distance(centroids[c]);
          if (distance < bestDistance) {
            bestDistance = distance;
            bestCluster = c;
          }
        }

        assignments.add(bestCluster);
      }

      // 更新聚类中心
      for (int c = 0; c < centroids.length; c++) {
        final clusterPixels = <Color>[];
        for (int i = 0; i < assignments.length; i++) {
          if (assignments[i] == c) {
            clusterPixels.add(pixels[i]);
          }
        }

        if (clusterPixels.isNotEmpty) {
          int sumR = 0, sumG = 0, sumB = 0;
          for (final p in clusterPixels) {
            sumR += p.r;
            sumG += p.g;
            sumB += p.b;
          }
          centroids[c] = Color(
            (sumR ~/ clusterPixels.length),
            (sumG ~/ clusterPixels.length),
            (sumB ~/ clusterPixels.length),
          );
        }
      }
    }

    // 创建分割后的图像
    final result = img.Image(width: width, height: height);
    int pixelIdx = 0;

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final pixel = pixels[pixelIdx];
        final assignment = <int>[];
        double bestDistance = double.infinity;
        int bestCluster = 0;

        for (int c = 0; c < centroids.length; c++) {
          final distance = pixel.distance(centroids[c]);
          if (distance < bestDistance) {
            bestDistance = distance;
            bestCluster = c;
          }
        }

        final color = centroids[bestCluster];
        result.setPixelRgba(
          x,
          y,
          color.r,
          color.g,
          color.b,
          255,
        );

        pixelIdx++;
      }
    }

    return result;
  }
}

/// 简单的 RGB 颜色类
class Color {
  int r, g, b;

  Color(this.r, this.g, this.b);

  double distance(Color other) {
    final dr = (r - other.r).toDouble();
    final dg = (g - other.g).toDouble();
    final db = (b - other.b).toDouble();
    return (dr * dr + dg * dg + db * db);
  }
}
