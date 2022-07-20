//
//  SearchViewController.swift
//  GithubUserSearch
//
//  Created by joonwon lee on 2022/05/25.
//

import UIKit
import Combine

class SearchViewController: UIViewController {
    
    // TODO: //
    // [o]Search Controller
    // [o]collectionView 구성
    // [o]bind() data :
    // - 데이터 -> 뷰 : output
    //      - 검색된 사용자를 collectionView에 업데이트 하는 것 : snapshot 이용
    // - 사용자 인터렉션 대응 : input
    //      - 서치컨트롤러에서 텍스트를 가지고 -> 네트워크 요청
    
    @Published private(set) var users: [SearchResult] = []
    var subscription = Set<AnyCancellable>()
    
    @IBOutlet weak var collectionView: UICollectionView!
    
    typealias Item = SearchResult
    var datasource: UICollectionViewDiffableDataSource<Section, Item>?
    enum Section {
        case main
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        embedSearchControl()
        configureCollectionView()
        bind()
    }
    
    // Search Controller
    private func embedSearchControl() {
        self.navigationItem.title = "Search"
        
        let searchController = UISearchController(searchResultsController: nil)
        searchController.hidesNavigationBarDuringPresentation = false
        searchController.searchBar.placeholder = "songheeZoeyChoi"
        searchController.searchResultsUpdater = self
        searchController.searchBar.delegate = self
        self.navigationItem.searchController = searchController
    }
    
    // collectionView 구성 : data, presentation, layer
    private func configureCollectionView() {
        datasource = UICollectionViewDiffableDataSource<Section, Item>(collectionView: collectionView, cellProvider: { collectionView, indexPath, item in
            
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ResultCell", for: indexPath) as? ResultCell else { return nil }
            
            cell.user.text = item.login
            return cell
        })
        
        //layout//
        collectionView.collectionViewLayout = layout()
    }
    
    private func layout() -> UICollectionViewCompositionalLayout {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(60))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(60))
        let group = NSCollectionLayoutGroup.vertical(layoutSize: groupSize, subitems: [item])
        let section = NSCollectionLayoutSection(group: group)
        return UICollectionViewCompositionalLayout(section: section)
    }
    
    private func bind() {
        $users
            .receive(on: RunLoop.main)
            .sink { users in
                var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
                snapshot.appendSections([.main])
                snapshot.appendItems(users, toSection: .main)
                self.datasource?.apply(snapshot)
            }.store(in: &subscription)
        
        
    }

    
}

extension SearchViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        let keyword = searchController.searchBar.text
        print("search: \(keyword ?? "")")
    }
}

extension SearchViewController: UISearchBarDelegate {
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        print("Search Button Clicked: \(searchBar.text ?? "")")
        
        guard let keyword = searchBar.text, !keyword.isEmpty else {return}
        
        let base = "https://api.github.com/"
        let path = "search/users"
        let params: [String:String] = ["q":keyword]
        let header: [String:String] = ["Content-Type":"application/json"]
        
        var urlComponents = URLComponents(string: base + path)!
        let queryItem = params.map { (key: String, value: String) in
            return URLQueryItem(name: key, value: value)
        }
        urlComponents.queryItems = queryItem
        
        var request = URLRequest(url: urlComponents.url!)
        header.forEach { (key: String, value: String) in
            request.addValue(value, forHTTPHeaderField: key)
        }
        
        URLSession.shared.dataTaskPublisher(for: request)
            .map { $0.data } // data 받고
            .decode(type: SearchUserResponse.self, decoder: JSONDecoder())
            .map { $0.items }
            .replaceError(with: []) // error에 대한 처리
            .receive(on: RunLoop.main)
            .assign(to: \.users, on: self)
            .store(in: &subscription)
    }
}
