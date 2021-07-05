//
//  PGLHelpPagesController.swift
//  WillsFilterTool
//
//  Created by Will on 7/5/21.
//  Copyright © 2021 Will Loew-Blosser. All rights reserved.
//

import UIKit

class PGLHelpPagesController: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate  {

    var helpPages: [(imageName: String, imageText: String )] = [
            ("TouchSwipePick2",
                "Touch the filter, then Swipe and Pick an image from your photo library") ,
            ("PlusButton",
                "+ button adds a new filter"),
            ("SurrealityFilter1",
                "Select a new filter" ),
            ( "SurrealityFilterParm",
                "Select a filter parm, and adjust the control"),
        ( "longPress",
            "Long touch for filter description"),
        ( "swipeMore",
            "Swipe then touch More or Pick"),
        ( "imagePick",
            "Pick an album, touch images to pick"),
        ( "cropOK",
            "Swipe on a parm cell for actions")
            ]

    var currentIndex: Int!
    var instructionText: String!

    override init() {
        super .init()
        if let viewController = viewPhotoCommentController(currentIndex ?? 0) {
          let viewControllers = [viewController]

          setViewControllers(viewControllers,
                             direction: .forward,
                             animated: false,
                             completion: nil)
        }

    }
    func viewPhotoCommentController(_ index: Int) -> PGLHelpSinglePage? {
      guard
        let storyboard = storyboard,
        let page = storyboard.instantiateViewController(withIdentifier: "PGLHelpSinglePage") as? PGLHelpSinglePage
        else {
          return nil
      }
        page.photoIndex = index
        page.photoName = helpPages[index].imageName
        page.instructionText = helpPages[index].imageText

      return page
    }

  func pageViewController(_ pageViewController: UIPageViewController,
                          viewControllerBefore viewController: UIViewController) -> UIViewController? {
    if let viewController = viewController as? PGLHelpSinglePage,
      let index = viewController.photoIndex,
      index > 0 {
      return viewPhotoCommentController(index - 1)
    }

    return nil
  }

  func pageViewController(_ pageViewController: UIPageViewController,
                          viewControllerAfter viewController: UIViewController) -> UIViewController? {
    if let viewController = viewController as? PGLHelpSinglePage,
      let index = viewController.photoIndex,
      (index + 1) < helpPages.count {
      return viewPhotoCommentController(index + 1)
    }

    return nil
  }

  func presentationCount(for pageViewController: UIPageViewController) -> Int {
    return helpPages.count
  }

  func presentationIndex(for pageViewController: UIPageViewController) -> Int {
    return currentIndex ?? 0
  }

}
