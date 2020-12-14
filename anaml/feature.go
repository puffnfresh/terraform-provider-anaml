package anaml

import (
	"encoding/json"
	"fmt"
	"net/http"
	"strings"
)

func (c *Client) GetFeature(featureID string) (*Feature, error) {
	req, err := http.NewRequest("GET", fmt.Sprintf("%s/feature/%s", c.HostURL, featureID), nil)
	if err != nil {
		return nil, err
	}

	body, err := c.doRequest(req)
	if err != nil {
		return nil, err
	}

	if body == nil {
		return nil, nil
	}

	feature := Feature{}
	err = json.Unmarshal(body, &feature)
	if err != nil {
		return nil, err
	}

	return &feature, nil
}

func (c *Client) CreateFeature(creationRequest Feature) (*Feature, error) {
	rb, err := json.Marshal(creationRequest)
	if err != nil {
		return nil, err
	}

	req, err := http.NewRequest("POST", fmt.Sprintf("%s/feature", c.HostURL), strings.NewReader(string(rb)))
	if err != nil {
		return nil, err
	}

	body, err := c.doRequest(req)
	if err != nil {
		return nil, err
	}

	var V int
	err = json.Unmarshal(body, &V)
	if err != nil {
		return nil, err
	}

	creationRequest.Id = V
	return &creationRequest, nil
}

func (c *Client) UpdateFeature(featureID string, creationRequest Feature) error {
	rb, err := json.Marshal(creationRequest)
	if err != nil {
		return err
	}

	req, err := http.NewRequest("PUT", fmt.Sprintf("%s/feature/%s", c.HostURL, featureID), strings.NewReader(string(rb)))
	if err != nil {
		return err
	}

	_, err = c.doRequest(req)
	if err != nil {
		return err
	}

	return nil
}

func (c *Client) DeleteFeature(featureID string) error {
	req, err := http.NewRequest("DELETE", fmt.Sprintf("%s/feature/%s", c.HostURL, featureID), nil)
	if err != nil {
		return err
	}

	_, err = c.doRequest(req)
	if err != nil {
		return err
	}

	return nil
}