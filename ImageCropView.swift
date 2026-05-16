import SwiftUI

struct ImageCropView: View {
    let image: UIImage
    let onCrop: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        CropController(image: image, onCrop: { cropped in
            onCrop(cropped)
            dismiss()
        }, onDismiss: { dismiss() })
            .ignoresSafeArea()
    }
}

private struct CropController: UIViewControllerRepresentable {
    let image: UIImage
    let onCrop: (UIImage) -> Void
    let onDismiss: () -> Void

    func makeUIViewController(context: Context) -> CropVC {
        CropVC(image: image, onCrop: onCrop, onDismiss: onDismiss)
    }

    func updateUIViewController(_ vc: CropVC, context: Context) {}
}

private final class CropVC: UIViewController, UIScrollViewDelegate {
    private let originalImage: UIImage
    private let onCrop: (UIImage) -> Void
    private let onDismiss: () -> Void

    private var scrollView: UIScrollView!
    private var imageView: UIImageView!
    private var overlayView: UIView!
    private var bottomBar: UIView!
    private let ratio: CGFloat = 3.0 / 4.0

    private let outputSize = CGSize(width: 1080, height: 1440)

    init(image: UIImage, onCrop: @escaping (UIImage) -> Void, onDismiss: @escaping () -> Void) {
        self.originalImage = image
        self.onCrop = onCrop
        self.onDismiss = onDismiss
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override var prefersStatusBarHidden: Bool { true }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        // ScrollView pour zoom + pan
        scrollView = UIScrollView()
        scrollView.delegate = self
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceVertical = true
        scrollView.alwaysBounceHorizontal = true
        scrollView.bouncesZoom = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        imageView = UIImageView(image: originalImage)
        imageView.contentMode = .scaleAspectFill
        imageView.isUserInteractionEnabled = true
        scrollView.addSubview(imageView)

        // Overlay avec découpe 4:5
        overlayView = UIView()
        overlayView.isUserInteractionEnabled = false
        overlayView.backgroundColor = .clear
        overlayView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(overlayView)

        // Barre du bas
        bottomBar = UIView()
        bottomBar.backgroundColor = UIColor.black.withAlphaComponent(0.9)
        bottomBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bottomBar)

        let cancelBtn = UIButton(type: .system)
        cancelBtn.setTitle(loc("crop.cancel"), for: .normal)
        cancelBtn.setTitleColor(.white, for: .normal)
        cancelBtn.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .medium)
        cancelBtn.addTarget(self, action: #selector(didTapCancel), for: .touchUpInside)
        cancelBtn.translatesAutoresizingMaskIntoConstraints = false
        bottomBar.addSubview(cancelBtn)

        let cropBtn = UIButton(type: .system)
        var cfg = UIButton.Configuration.plain()
        cfg.title = loc("crop.confirm")
        cfg.baseForegroundColor = .white
        cfg.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 28, bottom: 10, trailing: 28)
        cropBtn.configuration = cfg
        cropBtn.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .bold)
        cropBtn.backgroundColor = UIColor.white.withAlphaComponent(0.15)
        cropBtn.layer.cornerRadius = 8
        cropBtn.addTarget(self, action: #selector(didTapCrop), for: .touchUpInside)
        cropBtn.translatesAutoresizingMaskIntoConstraints = false
        bottomBar.addSubview(cropBtn)

        NSLayoutConstraint.activate([
            // ScrollView = toute la vue
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            overlayView.topAnchor.constraint(equalTo: view.topAnchor),
            overlayView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            overlayView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            bottomBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            bottomBar.heightAnchor.constraint(equalToConstant: 80),

            cancelBtn.leadingAnchor.constraint(equalTo: bottomBar.leadingAnchor, constant: 24),
            cancelBtn.centerYAnchor.constraint(equalTo: bottomBar.centerYAnchor, constant: -12),

            cropBtn.centerXAnchor.constraint(equalTo: bottomBar.centerXAnchor),
            cropBtn.centerYAnchor.constraint(equalTo: cancelBtn.centerYAnchor),
        ])
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        setupZoom()
        drawOverlay()
    }

    private var cropRect: CGRect {
        let barHeight: CGFloat = 80 + view.safeAreaInsets.bottom
        let availableHeight = view.bounds.height - barHeight
        let cropHeight = availableHeight * 0.85
        let cropWidth = cropHeight * ratio
        let x = (view.bounds.width - cropWidth) / 2
        let y = (availableHeight - cropHeight) / 2
        return CGRect(x: x, y: y, width: cropWidth, height: cropHeight)
    }

    private func setupZoom() {
        let imgSize = originalImage.size
        guard imgSize.width > 0, imgSize.height > 0 else { return }
        
        let crop = cropRect

        // L'image remplit au moins la zone de crop
        let imgRatio = imgSize.width / imgSize.height
        var fitSize: CGSize
        if imgRatio > ratio {
            fitSize = CGSize(width: crop.height * imgRatio, height: crop.height)
        } else {
            fitSize = CGSize(width: crop.width, height: crop.width / imgRatio)
        }

        imageView.frame = CGRect(origin: .zero, size: fitSize)
        scrollView.contentSize = fitSize

        // Centrer dans la zone visible
        _ = max((view.bounds.width - fitSize.width) / 2, crop.origin.x)
        let insetY = max((view.bounds.height - fitSize.height) / 2, 0)
        scrollView.contentInset = UIEdgeInsets(top: insetY, left: 0, bottom: insetY, right: 0)
        
        // Zoom min : l'image remplit exactement la zone crop
        let minZoom = min(crop.width / fitSize.width, crop.height / fitSize.height)
        scrollView.minimumZoomScale = minZoom
        scrollView.maximumZoomScale = max(minZoom, 3.0)
        scrollView.zoomScale = minZoom
        
        // Défilement par défaut au centre
        let offsetX = (fitSize.width * minZoom - crop.width) / 2 + crop.origin.x
        let offsetY = (fitSize.height * minZoom - crop.height) / 2 + crop.origin.y
        scrollView.contentOffset = CGPoint(x: offsetX, y: offsetY)
    }

    private func drawOverlay() {
        overlayView.layer.sublayers?.removeAll()
        
        let crop = cropRect

        // Fond sombre avec trou
        let path = UIBezierPath(rect: overlayView.bounds)
        path.append(UIBezierPath(rect: crop))
        path.usesEvenOddFillRule = true

        let dim = CAShapeLayer()
        dim.path = path.cgPath
        dim.fillRule = .evenOdd
        dim.fillColor = UIColor.black.withAlphaComponent(0.6).cgColor
        overlayView.layer.addSublayer(dim)

        // Bord blanc
        let border = CAShapeLayer()
        border.path = UIBezierPath(rect: crop).cgPath
        border.strokeColor = UIColor.white.cgColor
        border.lineWidth = 2
        border.fillColor = UIColor.clear.cgColor
        overlayView.layer.addSublayer(border)

        // Grille 3×3
        let grid = UIBezierPath()
        let w = crop.width / 3
        let h = crop.height / 3
        for i in 1...2 {
            grid.move(to: CGPoint(x: crop.minX + w * CGFloat(i), y: crop.minY))
            grid.addLine(to: CGPoint(x: crop.minX + w * CGFloat(i), y: crop.maxY))
            grid.move(to: CGPoint(x: crop.minX, y: crop.minY + h * CGFloat(i)))
            grid.addLine(to: CGPoint(x: crop.maxX, y: crop.minY + h * CGFloat(i)))
        }
        let gridLayer = CAShapeLayer()
        gridLayer.path = grid.cgPath
        gridLayer.strokeColor = UIColor.white.withAlphaComponent(0.4).cgColor
        gridLayer.lineWidth = 0.5
        overlayView.layer.addSublayer(gridLayer)
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        imageView
    }

    @objc private func didTapCancel() { onDismiss() }

    @objc private func didTapCrop() {
        let crop = cropRect
        
        // Rectangle visible dans le content de la scrollView
        let visibleRect = CGRect(
            x: scrollView.contentOffset.x + crop.origin.x,
            y: scrollView.contentOffset.y + crop.origin.y,
            width: crop.width,
            height: crop.height
        )
        
        let zoom = scrollView.zoomScale
        let imgSize = originalImage.size

        // Convertir en coordonnées image
        let scale = imgSize.width / (imageView.bounds.width * zoom)
        let cropInImage = CGRect(
            x: (visibleRect.origin.x / zoom) * scale,
            y: (visibleRect.origin.y / zoom) * scale,
            width: (visibleRect.width / zoom) * scale,
            height: (visibleRect.height / zoom) * scale
        )

        guard let cgImage = originalImage.cgImage?.cropping(to: cropInImage) else { return }
        let cropped = UIImage(cgImage: cgImage, scale: originalImage.scale, orientation: originalImage.imageOrientation)
        
        // Redimensionner en taille fixe 1080×1350
        let renderer = UIGraphicsImageRenderer(size: outputSize)
        let final = renderer.image { _ in
            cropped.draw(in: CGRect(origin: .zero, size: outputSize))
        }
        
        onCrop(final)
    }
}
