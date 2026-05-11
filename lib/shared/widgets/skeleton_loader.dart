import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Skeleton loader para cards
class SkeletonCard extends StatefulWidget {
  final double height;
  final double? width;
  final BorderRadius? borderRadius;

  const SkeletonCard({
    super.key,
    this.height = 100,
    this.width,
    this.borderRadius,
  });

  @override
  State<SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<SkeletonCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _animation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius ??
                BorderRadius.circular(AppBorderRadius.md),
            gradient: LinearGradient(
              begin: Alignment(_animation.value - 1, 0),
              end: Alignment(_animation.value, 0),
              colors: const [
                Color(0xFF3d2b5e),
                Color(0xFF4d3b6e),
                Color(0xFF3d2b5e),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Skeleton loader para texto
class SkeletonText extends StatelessWidget {
  final double width;
  final double height;

  const SkeletonText({
    super.key,
    this.width = 150,
    this.height = 16,
  });

  @override
  Widget build(BuildContext context) {
    return SkeletonCard(
      width: width,
      height: height,
      borderRadius: BorderRadius.circular(AppBorderRadius.sm),
    );
  }
}

/// Skeleton loader para avatar circular
class SkeletonAvatar extends StatelessWidget {
  final double size;

  const SkeletonAvatar({
    super.key,
    this.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    return SkeletonCard(
      width: size,
      height: size,
      borderRadius: BorderRadius.circular(AppBorderRadius.round),
    );
  }
}

/// Skeleton para lista de cards
class SkeletonList extends StatelessWidget {
  final int itemCount;
  final double itemHeight;

  const SkeletonList({
    super.key,
    this.itemCount = 5,
    this.itemHeight = 100,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, index) => SkeletonCard(height: itemHeight),
    );
  }
}

/// Skeleton para grid de categorias
class SkeletonCategoryGrid extends StatelessWidget {
  final int itemCount;

  const SkeletonCategoryGrid({
    super.key,
    this.itemCount = 4,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: AppSpacing.md,
        mainAxisSpacing: AppSpacing.md,
        childAspectRatio: 1.1,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) => const SkeletonCard(height: 150),
    );
  }
}

/// Skeleton para página de dashboard
class SkeletonDashboard extends StatelessWidget {
  const SkeletonDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SkeletonText(width: 200, height: 28),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: const [
              Expanded(child: SkeletonCard(height: 120)),
              SizedBox(width: AppSpacing.md),
              Expanded(child: SkeletonCard(height: 120)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: const [
              Expanded(child: SkeletonCard(height: 120)),
              SizedBox(width: AppSpacing.md),
              Expanded(child: SkeletonCard(height: 120)),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          const SkeletonText(width: 180, height: 24),
          const SizedBox(height: AppSpacing.md),
          const SkeletonCard(height: 300),
        ],
      ),
    );
  }
}
