{View} = require 'atom-space-pen-views'
etch = require 'etch'
fuzzyFilter = null # defer until used
ProjectItem = require './project-item'
projects = require './projects'

projectClasses = "luna-welcome__tile "
tutorialClasses = projectClasses + "luna-welcome__tile--tutorial"
recentClasses = projectClasses + "luna-welcome__tile--recent"
privateNewClasses = projectClasses + 'luna-welcome__tile--add-new'
comunnityNewClasses = projectClasses + 'luna-welcome__tile--add-new'

module.exports =
class LunaWelcomeTab extends View
    constructor: (@codeEditor) ->
        super

    @content: ->
        @div class: 'luna-welcome-scroll', =>

            @div class: 'luna-welcome', =>

                @div class: 'luna-welcome__header', =>

                    @h1 class: 'luna-welcome__title', 'Welcome to Luna Studio'

                    @div class: 'luna-welcome__header__menu', =>

                        @input
                            class: 'luna-input luna-input--search luna-welcome-search native-key-bindings'
                            type: 'search'
                            placeholder: 'Search'
                            outlet: 'searchInput'

                        @div class: 'luna-welcome__header__menu__links', =>
                            @a
                                class: 'luna-welcome-link luna-welcome-link--forum'
                                href: "http://luna-lang.org"
                                'forum'

                            @a
                                class: 'luna-welcome-link luna-welcome-link--chat'
                                href: "http://luna-lang.org"
                                'chat'

                @div class: 'luna-welcome__body', =>

                    @div class: 'luna-welcome__block luna-welcome__block--projects', =>
                        @div
                            class: 'luna-welcome__section luna-welcome__section--search-results'
                            outlet: 'searchResultsSection'
                            =>
                                @h2 class: 'luna-welcome__section__title icon icon-search', 'Search results'
                                @div class: 'luna-welcome__section__container', outlet: 'searchResultsContainer', =>

                        @div
                            class: 'luna-welcome__section luna-welcome__section--tutorials'
                            outlet: 'tutorialsSection'
                            =>
                                @h2 class: 'luna-welcome__section__title icon icon-book', 'Tutorials'
                                @div class: 'luna-welcome__section__container', outlet: 'tutorialsContainer', =>

                        @div
                            class: 'luna-welcome__section luna-welcome__section--private',
                            outlet: 'privateSection'
                            =>
                                @h2 class: 'luna-welcome__section__title icon icon-person', 'Private'
                                @div class: 'luna-welcome__section__container', outlet: 'privateContainer', =>

                        @div
                            class: 'luna-welcome__section luna-welcome__section--community'
                            outlet: 'communitySection'
                            =>
                                @h2 class: 'luna-welcome__section__title icon icon-organization',  'Community'
                                @div  class: 'luna-welcome__section__container', outlet: 'communityContainer', =>

    initialize: =>
        @tutorialItems = []
        @privateItems = []
        @privateNew = new ProjectItem({name: 'New Project', uri: null}, privateNewClasses, (progress, finalize) =>
            finalize()
            projects.temporaryProject.open()
            @detach())
        @communityItems = []
        @comunnityNew = new ProjectItem({name: 'New Project', uri: null}, comunnityNewClasses, (progress, finalize) =>
            finalize()
            atom.confirm
                message: "Not supported yet"
                detailedMessage: "Community projects are not supported yet."
                buttons:
                    Ok: -> )
        @searchInput.on 'search', @search
        @searchInput.on 'keyup', @search

        @hideSearchResults()
        projects.recent.load (recentProjectPath) =>
            item = new ProjectItem {name: recentProjectPath}, recentClasses, (progress, finalize) =>
                progress 0.5
                projects.closeAllFiles()
                atom.project.setPaths [recentProjectPath]
                finalize()
                @detach()
            @privateItems.push(item)
            @privateContainer.append(item.element)
        projects.tutorial.list (tutorials) =>
            if tutorials.length == 0
                @tutorialsContainer[0].innerText = 'Internet connection required.'
            else
                @tutorialsContainer[0].innerText = ''
            for tutorial in tutorials
                item = new ProjectItem(tutorial, tutorialClasses, (progress, finalize) =>
                    projects.tutorial.open(tutorial, progress, =>
                        finalize()
                        @detach()))
                @tutorialItems.push(item)
                @tutorialsContainer.append(item.element)

    getFilterKey: ->
        return 'name'

    attach: (@mode) ->
        @panel ?= atom.workspace.addModalPanel({item: this, visible: false})
        @previouslyFocusedElement = document.activeElement
        @panel.show()
        @searchInput.focus()

    detach: ->
        if @panel.isVisible and @panel.isVisible()
            @searchInput[0].value = ''
            @hideSearchResults()
            @panel.hide()
            @previouslyFocusedElement?.focus()

    search: =>
        filterQuery = @searchInput[0].value
        if filterQuery == ""
            @hideSearchResults()
        else
            fuzzyFilter ?= require('fuzzaldrin').filter
            allItems = @tutorialItems.concat(@privateItems)
            filteredItems = fuzzyFilter(allItems, filterQuery, key: @getFilterKey())
            @showSearchResults filteredItems


    showSearchResults: (searchResults) =>
        @searchResultsContainer.empty()
        for item in searchResults
            @searchResultsContainer.append item.element

        @communitySection.hide()
        @privateSection.hide()
        @tutorialsSection.hide()
        @searchResultsSection.show()

    hideSearchResults: =>
        @privateContainer.empty()
        @privateContainer.append(@privateNew.element)
        for privateItem in @privateItems
            @privateContainer.append(privateItem.element)

        @tutorialsContainer.empty()
        for tutorialItem in @tutorialItems
            @tutorialsContainer.append(tutorialItem.element)

        @communityContainer.empty()
        @communityContainer.append(@comunnityNew.element)
        for communityItem in @communityItems
            @communityContainer.append(communityItem.element)


        @searchResultsSection.hide()
        @communitySection.show()
        @privateSection.show()
        @tutorialsSection.show()

    getTitle: -> 'Welcome'
