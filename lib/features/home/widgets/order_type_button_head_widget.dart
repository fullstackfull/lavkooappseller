import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/custom_asset_image_widget.dart';
import 'package:syriacosmeticsmanger/features/order/controllers/order_controller.dart';
import 'package:syriacosmeticsmanger/utill/styles.dart';

class OrderTypeButtonHeadWidget extends StatefulWidget {
  final String? text;
  final String? subText;
  final Color? color;
  final Color? circleColor;
  final int index;
  final Function? callback;
  final int? numberOfOrder;
  final String? image;
  final String? percentage;

  const OrderTypeButtonHeadWidget({
    super.key,
    required this.text,
    this.subText,
    this.color,
    required this.index,
    required this.callback,
    required this.numberOfOrder,
    required this.circleColor,
    required this.image,
    this.percentage,
  });

  @override
  State<OrderTypeButtonHeadWidget> createState() => _OrderTypeButtonHeadWidgetState();
}

class _OrderTypeButtonHeadWidgetState extends State<OrderTypeButtonHeadWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideUp;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _slideUp = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // فحص ما إذا كانت النسبة سالبة (هبوط) أو موجبة (صعود) بناءً على النص القادم
    final String percentText = widget.percentage ?? "0%";
    final bool isDecrease = percentText.startsWith('-');

    // تحديد اللون والاتجاه بناءً على الحالة
    final Color statusColor = isDecrease ? Colors.red : (widget.circleColor ?? const Color(0xFF1F7A55));
    final IconData statusIcon = isDecrease ? Icons.arrow_downward : Icons.arrow_upward;

    return SlideTransition(
      position: _slideUp,
      child: FadeTransition(
        opacity: _fadeIn,
        child: InkWell(
          onTap: () {
            Provider.of<OrderController>(context, listen: false).setIndex(context, widget.index);
            if (widget.callback != null) widget.callback!();
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // الجزء العلوي: الأيقونة والرقم
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        height: 38,
                        width: 38,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: widget.circleColor?.withValues(alpha: 0.15) ?? const Color(0xFF1F7A55).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: CustomAssetImageWidget(
                          widget.image!,
                          color: widget.circleColor ?? const Color(0xFF1F7A55),
                        ),
                      ),
                      Text(
                        widget.numberOfOrder.toString(),
                        style: robotoBold.copyWith(
                          color: isDark ? Colors.white : const Color(0xFF1A1E1C),
                          fontSize: 20,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),

                  // عنوان الطلبات
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.text!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: robotoMedium.copyWith(
                            color: isDark ? Colors.grey[400] : const Color(0xFF7E9A8E),
                            fontSize: 12,
                          ),
                        ),
                      ),
                      if (widget.subText != null && widget.subText!.isNotEmpty)
                        Text(
                          widget.subText!,
                          style: robotoMedium.copyWith(
                            fontSize: 12,
                            color: isDark ? Colors.grey[400] : const Color(0xFF7E9A8E),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // الجزء السفلي: النسبة المئوية والسهم المتحول ديناميكياً مع الرسم البياني
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              statusIcon, // يتغير تلقائياً (للأسفل إن كان سالب، للأعلى إن كان موجب)
                              size: 10,
                              color: statusColor,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              percentText,
                              style: robotoBold.copyWith(
                                fontSize: 10,
                                color: statusColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isDecrease ? Icons.trending_down : Icons.trending_up,
                            size: 16,
                            color: statusColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isDecrease ? "Down" : "Up",
                            style: robotoMedium.copyWith(
                              fontSize: 11,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// كلاس الرسم الموجي
// كلاس الرسم الموجي المعدل ليتبع اتجاه النسبة (صعوداً أو هبوطاً)
class WavePainter extends CustomPainter {
  final Color color;
  final bool isDecrease; // متغير لتحديد هل هي حالة هبوط أم صعود

  WavePainter({required this.color, required this.isDecrease});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    final path = Path();

    if (isDecrease) {
      // رسم موجة هابطة (تتجه للأسفل)
      path.moveTo(0, size.height * 0.2);
      path.cubicTo(
        size.width * 0.25, size.height * 0.9,
        size.width * 0.4, size.height * 0.1,
        size.width * 0.6, size.height * 0.7,
      );
      path.cubicTo(
        size.width * 0.75, size.height * 0.9,
        size.width * 0.9, size.height * 0.3,
        size.width, size.height * 0.8,
      );
    } else {
      // رسم موجة صاعدة (تتجه للأعلى)
      path.moveTo(0, size.height * 0.8);
      path.cubicTo(
        size.width * 0.25, size.height * 0.1,
        size.width * 0.4, size.height * 0.9,
        size.width * 0.6, size.height * 0.4,
      );
      path.cubicTo(
        size.width * 0.75, size.height * 0.1,
        size.width * 0.9, size.height * 0.6,
        size.width, size.height * 0.3,
      );
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant WavePainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.isDecrease != isDecrease;
  }
}