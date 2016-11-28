# frozen_string_literal: true
module CatalogueHelpers
  def baseurl
    if environment? :development
      ''
    elsif environment? :production
      '/publications/romanmosaics'
    end
  end

  def og_image_path
    "http://www.getty.edu#{baseurl}/assets/images/og_cover.jpg"
  end

  def plates_lookup(cat_num)
    plates = data.plates
    entry = plates.find { |i| i[:cat] == cat_num }
    return false if entry.nil?

    {
      :cat => entry[:cat],
      :images => entry[:images].map(&:to_json)
    }
  end

  def catalogue_lookup(cat_num)
    data.catalogue.find { |c| c[:cat_no] == cat_num }
  end

  def author_name
    author = data.book.creators.first
    "#{data.book.creators[0].first_name} #{data.book.creators[0].last_name} and #{data.book.creators[1].first_name} #{data.book.creators[1].last_name}"
  end

  def page_title
    title   = data.book.title
    authors = data.book.creators
    page    = current_page.data

    if page.cat
      if page.cat.is_a? Array
        "Cats. #{page.cat.first}-#{page.cat.last} | #{title.short}"
      else
        "Cat. #{page.cat} | #{title.short}"
      end
    elsif page.sort_order == 0
      "#{title.main} | #{authors.first.first_name} #{authors.first.last_name}"
    else
      "#{page.title} | #{title.short}"
    end
  end

  # --------------------------------------------------------------------------
  # Book info methods
  # Used to build up the complex strings used in the citation partial
  def book_info_chicago
    book = data.book
    path = current_path.gsub('index.html', '')
    %(
      In <em>#{book.title.main}</em>,
      by #{author_name}.
      #{book.publisher_location}:
      #{book.publisher},
      #{book.pub_date.year}.
      <span class="force-wrap">#{permalink}/#{path}</span>.
    )
  end

  def book_info_mla
    book = data.book
    path = current_path.gsub('index.html', '')
    %(
      <em>#{book.title.main}</em>. By #{author_name}.
      #{book.publisher_location}:
      #{book.publisher_short}, #{book.pub_date.year}.
      <span class="cite-current-date">DD Mon. YYYY</span>
      <<span class="force-wrap">#{permalink}/#{path}</span>>.
    )
  end

  # --------------------------------------------------------------------------
  # Citation author method
  # Returns correct author info for citation partial
  def citation_author
    page = current_page.data
    return default_author unless page.author
    if page.author.size > 1
      %(#{page.author[0].last_name}, #{page.author[0].first_name},
        and #{page.author[1].first_name} #{page.author[1].last_name})
    else
      "#{page.author.first.last_name}, #{page.author.first.first_name}"
    end
  end

  # --------------------------------------------------------------------------
  # Default author
  # Return default author name in citation format (last, first)
  def default_author
    book = data.book
    if book.creators.size > 1
      %(#{book.creators[0].last_name}, #{book.creators[0].first_name},
        and #{book.creators[1].first_name} #{book.creators[1].last_name})
    else
      "#{book.creators.first.last_name}, #{book.creators.first.first_name}"
    end
  end

  def permalink
    data.book.editions.find { |edition| edition.name == 'Online' }.link
  end

  # --------------------------------------------------------------------------
  # Data attribute methods
  # The following helper methods provide data which can be stashed in data-
  # attributes of elements in templates. Use them to store information from
  # YAML data files for future consumption by front-end JS.

  # Define Term helper method
  # Expects a word (string)
  # looks for term in the definitions.yml file
  # Returns definition_short if that exists, or else returns full definition
  # Also returns plural form if that exists
  def define_term(word)
    term = data.definitions.find { |entry| entry.id == word }
    if term
      # term is singular
      definition = term.definition_short || term.definition
    else
      term = data.definitions.find { |entry| entry.plural == word }
      unless term.nil?
        definition = "Plural of the word <em>#{term.id}</em>: "
        definition += term.definition_short || term.definition
      end
    end

    definition unless definition.nil?
  end

  # Location helper method
  # Expects a location ID (string)
  # Looks up the location in locations.yml and returns its id
  # In the future this method could do more if more data exists in this file
  def location(loc_id)
    data.locations.find { |loc| loc.id == loc_id }.id
  end

  # Pic helper method
  # Expects a pic id (string)
  # Returns a serialized json object
  def pic(pic_id)
    data.pics.find { |pic| pic.id == pic_id }.to_json
  end

  # --------------------------------------------------------------------------
  # Lookup Catalogue Entry
  # expects a cat number (int)
  # returns a hash of entry data or nil if no entry is found
  def lookup_entry(cat)
    data.catalogue.find { |entry| entry.cat == cat }
  end

  # Lookup Catalogue Entries (plural)
  # expects an array of cat numbers (int)
  # returns an array of entry data hashes or nil if no entry is found
  def lookup_entries(group)
    data.catalogue.find_all { |entry| group.include? entry.cat }
  end

  # --------------------------------------------------------------------------
  # Collection link method
  # Expects a cat number (int)
  # Outputs a HAML tag with link to the Getty collection page for the object
  def collection_link(cat)
    url    = 'http://www.getty.edu/art/collection/objects/'
    obj_id = lookup_entry(cat).dor_id
    return false if obj_id.nil?
    haml_tag :a, :class => 'collection-link',
                 :target => 'blank',
                 :title  => "View this item on the Getty's Collection Pages.",
                 :href   => "#{url}#{obj_id}" do
      haml_tag :i, :class => 'ion-link'
    end
  end

  # --------------------------------------------------------------------------
  # Location Link method
  # Expects two arguments: first, the desired link text
  # Second: a url pattern like so: "/catalogue/italy.html#loc_1524"
  # Where /catalogue/italy.html is the relevant map page
  # and #loc_xxxx is the location id of the point to appear on the map
  # as referenced in the geojson file
  def location_link(text, destination)
    html = content_tag :sup, :class => 'location-link' do
      tag :i, :class => 'ion-ios-location-outline'
      link_to destination.to_s, :title => 'View this location on the map' do
        tag :i, :class => 'ion-ios-location-outline'
      end
    end
    concat_safe_content("#{text}#{html}")
  end

  # --------------------------------------------------------------------------
  # Previous Chapter Path
  # Does not expect an argument (pulls data from current_page)
  # Returns the path of the previous chapter or false if prev chapter does not
  # exist. This method also checks if the chapter is the first in a given
  # section and pulls the last chapter from the previous section if so.
  def prev_chapter_path
    return false unless current_page.data.sort_order
    curr = current_page.data.sort_order
    frontmatter, catalogue, backmatter = catalogue_sections
    case curr
    when frontmatter.first.data.sort_order
      prev_chap = false
    when catalogue.first.data.sort_order
      prev_chap = frontmatter.last
    when backmatter.first.data.sort_order
      prev_chap = catalogue.last
    else
      prev_chap = sitemap.resources.find { |p| p.data.sort_order == curr - 1 }
    end
    prev_chap ? prev_chap : false
  end

  # Next Chapter Path
  # Does not expect an argument (pulls data from current_page)
  # Returns the path of the next chapter or false if next chapter does not
  # exist. This method also checks if the chapter is the last in a given
  # section and pulls the first chapter from the next section if so.
  def next_chapter_path
    return false unless current_page.data.sort_order
    curr = current_page.data.sort_order
    frontmatter, catalogue, backmatter = catalogue_sections
    case curr
    when frontmatter.last.data.sort_order
      next_chap = catalogue.first
    when catalogue.last.data.sort_order
      next_chap = backmatter.first
    when backmatter.last.data.sort_order
      next_chap = false
    else
      next_chap = sitemap.resources.find { |p| p.data.sort_order == curr + 1 }
    end
    next_chap ? next_chap : false
  end
end