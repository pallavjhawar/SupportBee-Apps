module Pipedrive
  module EventHandler
    def ticket_created
      ticket = payload.ticket
      requester = ticket.requester
      begin
        person = find_person(requester)
        html = ''
        
        if person
          html = existing_person_info(person)
        else
          person = create_person(requester)
          html = created_person_info(person) if person
        end

        if person
          update_note(person, ticket)
          comment_on_ticket(html, ticket)
        end
      rescue Exception => e
        puts "#{e.message}\n#{e.backtrace}"
        [500, e.message]
      end
      [200, "Ticket sent"]
    end
  end
end

module Pipedrive
  class Base < SupportBeeApp::Base
    string  :api_token, :required => true, :label => 'Pipedrive Auth Token'
    boolean :should_create_person, :default => true, :required => false, :label => 'Create a New Person in Pipedrive if one does not exist'

    white_list :should_create_person

    def find_person(requester)
      first_name = split_name(requester)
      response = http_get('http://api.pipedrive.com/v1/persons/find') do |req|
        req.headers['Accept'] = 'application/json'
        req.params['api_token'] = settings.api_token
        req.params['term'] = first_name
      end 
      body = response.body['data']
      person = body.select{|pe| pe['email'] == requester.email}.first if body
      person ? person : nil
    end
    
    def create_person(requester)
      return unless settings.should_create_person.to_s == '1'
      first_name = split_name(requester)
      person = http_post('http://api.pipedrive.com/v1/persons') do |req|
        req.headers['Content-Type'] = 'application/json'
        req.params['api_token'] = settings.api_token
        req.body = {name:first_name, email:[requester.email]}.to_json
      end
      return person.body['data']
    end

    def split_name(requester)
      first_name, last_name = requester.name ? requester.name.split(' ') : [requester.email,'']
      return first_name
    end
   
    def update_note(person, ticket) 
      http_post('http://api.pipedrive.com/v1/notes') do |req|
        req.headers['Content-Type'] = 'application/json'
        req.params['api_token'] = settings.api_token
        req.body = {person_id:person['id'],content:generate_note_content(ticket)}.to_json
      end
    end

    def comment_on_ticket(html, ticket)
      ticket.comment(:html => html)
    end
 
    def existing_person_info(person)
      html = ""
      html << "<b> #{person['name']} </b><br/>" 
      html << "<br/>"
      html << person_link(person)
      html
    end

    def created_person_info(person)
      html = "Added <b> #{person['name']} </b> to Pipedrive...<br/> " 
      html << person_link(person)
      html
    end
    
    def person_link(person)
      "<a href='https://app.pipedrive.com/person/details/#{person['id']}'>View #{person['name']}'s profile on Pipedrive</a>"
    end
   
    def generate_note_content(ticket)
      note = "https://#{auth.subdomain}.supportbee.com/tickets/#{ticket.id}"
    end

  end
end

