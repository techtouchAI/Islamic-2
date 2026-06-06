import requests
from bs4 import BeautifulSoup
import json
import time
import re
import os
import argparse

def scrape():
    parser = argparse.ArgumentParser()
    parser.add_argument('--limit', type=int, default=0, help='Limit number of categories to scrape')
    parser.add_argument('--pages', type=int, default=0, help='Limit number of pages per category')
    args = parser.parse_args()

    url = 'https://www.sistani.org/arabic/qa/'
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
    }
    
    print(f"Fetching categories from {url}...")
    try:
        response = requests.get(url, headers=headers)
        response.raise_for_status()
        response.encoding = 'utf-8'
        soup = BeautifulSoup(response.text, 'html.parser')
    except Exception as e:
        print(f"Error fetching main page: {e}")
        return

    categories = []
    for a in soup.find_all('a', href=True):
        href = a['href']
        if '/arabic/qa/' in href and href != '/arabic/qa/':
            title = a.text.strip()
            if title:
                full_url = f"https://www.sistani.org{href}" if href.startswith('/') else href
                if full_url not in [c['url'] for c in categories]:
                    categories.append({'title': title, 'url': full_url})
                    
    print(f"Found {len(categories)} categories. Processing...")
    
    if args.limit > 0:
        categories = categories[:args.limit]
    
    fatawa_list = []
    category_id = 1
    
    for category in categories:
        cat_url = category['url']
        print(f"Scraping category {category_id}: {category['title']} - {cat_url}")
        
        qa_data = []
        page = 1
        
        while True:
            if args.pages > 0 and page > args.pages:
                break
                
            page_url = f"{cat_url}page/{page}/" if page > 1 else cat_url
            try:
                res = requests.get(page_url, headers=headers)
                if res.status_code != 200:
                    break
                res.encoding = 'utf-8'
                page_soup = BeautifulSoup(res.text, 'html.parser')
                elements = page_soup.find_all('div', class_='one-qa')
                if not elements:
                    break
                    
                for item in elements:
                    text = item.text.strip()
                    q_split = text.split("السؤال:")
                    if len(q_split) > 1:
                        a_split = q_split[1].split("الجواب:")
                        if len(a_split) > 1:
                            question = a_split[0].strip()
                            answer = a_split[1].strip()
                            answer = re.sub(r'sistani\.org/\d+', '', answer).strip()
                            qa_data.append({
                                "title": question,
                                "content": answer
                            })
                
                # Check for pagination (if there's fewer than 10 elements, it's likely the last page)
                if len(elements) < 10:
                    break
                    
                page += 1
                time.sleep(0.5)
            except Exception as e:
                print(f"Error on {page_url}: {e}")
                break
                
        if qa_data:
            # assign IDs to questions
            for idx, qa in enumerate(qa_data, 1):
                qa['id'] = idx
            
            fatawa_list.append({
                "id": category_id,
                "title": category['title'],
                "items": qa_data
            })
            category_id += 1
            
        time.sleep(0.5)

    print(f"Scraped {sum(len(c['items']) for c in fatawa_list)} items across {len(fatawa_list)} categories.")
    
    # Update content.json
    content_path = 'assets/data/content.json'
    print(f"Updating {content_path}...")
    
    try:
        with open(content_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
            
        if 'fatawa' not in data['sections']:
            data['sections']['fatawa'] = {
                "title": "الاستفتاءات (السيد السيستاني)",
                "icon": "gavel",
                "color": "0xFFD4AF37",
                "visible_home": True
            }
            
        data['fatawa_categories'] = fatawa_list
        
        with open(content_path, 'w', encoding='utf-8') as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
            
        print("Success!")
    except Exception as e:
        print(f"Error updating JSON: {e}")

if __name__ == '__main__':
    scrape()
