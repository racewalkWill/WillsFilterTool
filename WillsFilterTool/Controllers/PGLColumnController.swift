//
//  PGLColumnController.swift
//  WillsFilterTool
//
//  Created by Will on 10/30/21.
//  Copyright © 2021 Will Loew-Blosser. All rights reserved.
//

import UIKit
struct PGLControllerHolder: Hashable {
    let controller: UIViewController?
    let title: String

    let identifier = UUID()
    func hash(into hasher: inout Hasher) {
        hasher.combine(identifier)
    }
}

class PGLControllers {
    var stack = PGLStackController()
    var filter = PGLFilterTableController()
    var parm = PGLSelectParmController()

    func controllers() -> [PGLControllerHolder] {
        var controllerColumns = [PGLControllerHolder]()
        for aViewController in [ stack, filter, parm] {
            let newColumn = PGLControllerHolder.init(controller: aViewController, title: aViewController.title ?? "View" )
            controllerColumns.append(newColumn)
        }
        return controllerColumns
    }

}

class PGLColumnController: UIViewController {
    // for iPhone layouts show stack, filter, parm controllers
    // in single scrolling Collection View
    // based on  Modern Collection Views sample app class 'ConferenceVideoSessionsViewController'

    // model object refs..
    var appStack: PGLAppStack!
    var controllers = PGLControllers()
    var collectionView: UICollectionView! = nil
    var dataSource: UICollectionViewDiffableDataSource<Int, PGLControllerHolder>! = nil
        // need a viewController type for the section
        // a holder for the viewControllers?
    var currentSnapshot: NSDiffableDataSourceSnapshot<Int, PGLControllerHolder>! = nil

    static let titleElementKind = "title-element-kind"
    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.title = "PhotoStack"
        configureHierarchy()
        configureDataSource()
        // Do any additional setup after loading the view.
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}

extension PGLColumnController {
    func createLayout() -> UICollectionViewLayout {
        let sectionProvider = { (sectionIndex: Int,
            layoutEnvironment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection? in
            let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                                 heightDimension: .fractionalHeight(1.0))
            let item = NSCollectionLayoutItem(layoutSize: itemSize)

            // if we have the space, adapt and go 2-up + peeking 3rd item
//            let groupFractionalWidth = CGFloat(layoutEnvironment.container.effectiveContentSize.width > 500 ? 0.425 : 0.85)
            let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                                   heightDimension: .fractionalHeight(1.0))
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])

            let section = NSCollectionLayoutSection(group: group)
            section.orthogonalScrollingBehavior = .none
            section.interGroupSpacing = 20
            section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20)

            let titleSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                                  heightDimension: .estimated(44))
            let titleSupplementary = NSCollectionLayoutBoundarySupplementaryItem(
                layoutSize: titleSize,
                elementKind: (PGLColumnController.titleElementKind),
                alignment: .top)
            section.boundarySupplementaryItems = [titleSupplementary]
            return section
        }

        let config = UICollectionViewCompositionalLayoutConfiguration()
        config.interSectionSpacing = 20

        let layout = UICollectionViewCompositionalLayout(
            sectionProvider: sectionProvider, configuration: config)
        return layout
        }

}

extension PGLColumnController {
    func configureHierarchy() {
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: createLayout())
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .systemBackground
        view.addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
    }
    func configureDataSource() {

        let cellRegistration = UICollectionView.CellRegistration
        <ControllerColumnCell, PGLControllerHolder> { (cell, indexPath, controllerHolder) in
            // Populate the cell with our controller.
            cell.titleLabel.text = controllerHolder.title
            cell.categoryLabel.text = ""
            cell.showsLargeContentViewer = true
            cell.contentView.addSubview((controllerHolder.controller?.view)!)

        }

        dataSource = UICollectionViewDiffableDataSource
        <Int, PGLControllerHolder>(collectionView: collectionView) {
            (collectionView: UICollectionView, indexPath: IndexPath, column: PGLControllerHolder ) -> UICollectionViewCell? in
            // Return the cell.
            return collectionView.dequeueConfiguredReusableCell(using: cellRegistration, for: indexPath, item: column)
        }

        let supplementaryRegistration = UICollectionView.SupplementaryRegistration
        <TitleSupplementaryView>(elementKind: PGLColumnController.titleElementKind) {
            (supplementaryView, string, indexPath) in
            if let snapshot = self.currentSnapshot {
                // Populate the view with our section's description.
                let category = snapshot.sectionIdentifiers[indexPath.section]
                supplementaryView.label.text = "category"
            }
        }

        dataSource.supplementaryViewProvider = { (view, kind, index) in
            return self.collectionView.dequeueConfiguredReusableSupplementary(
                using: supplementaryRegistration, for: index)
        }

        currentSnapshot = NSDiffableDataSourceSnapshot<Int, PGLControllerHolder>()
        currentSnapshot.appendSections([0])
        currentSnapshot.appendItems(controllers.controllers())

        dataSource.apply(currentSnapshot, animatingDifferences: false)
    }
}
