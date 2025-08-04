# Local LLM Infrastructure Setup

> [!NOTE]
> The basis of this knowledge is the [Ollama](https://ollama.com/) Open-Source instance and [OpenWebUI](https://github.com/open-webui/open-webui)

<!-- TABLE OF CONTENTS -->
## Table of Contents

<ol>
  <li>
    <a href="#about-the-project">About The Project</a>
    <ul>
      <li><a href="#business-use-cases">Business Use Cases</a>
        <ol>
          <li><a href="#enterprise-data-analysis">Enterprise Data Analysis</a></li>
          <li><a href="#regulated-industries">Regulated Industries</a></li>
          <li><a href="#development-and-testing">Development and Testing</a></li>
          <li><a href="#operational-efficiency">Operational Efficiency</a></li>
        </ol>
      </li>
      <li><a href="#setup-use-cases">Setup Use Cases</a>
        <ol>
          <li><a href="#single-user-setup">Single User Setup</a></li>
          <li><a href="#small-team-setup">Small Team Setup</a></li>
          <li><a href="#enterprise-setup">Enterprise Setup</a></li>
        </ol>
      </li>
    </ul>
  </li>
  <li><a href="#roadmap">Roadmap</a></li>
  <li><a href="#acknowledgements">Acknowledgements</a></li>
</ol>

<!-- ABOUT THE PROJECT -->
## About The Project

Local/On-Premise LLM deployment is frequently requested at the time of writing, due to the increasing need for secured services and higher information security standards. However, due to business and technology development needs, our clients require the power and capabilities of large language models while maintaining complete control over their data and infrastructure.

This project is the setup documentation for building up a local or On-Premise LLM, ensuring that sensitive data never leaves the organization's network perimeter, even to private cloud by external cloud services.

### Use Cases

#### Enterprise Data Analysis

* Process confidential business documents, financial reports, and strategic plans without exposing sensitive information to third-party services
* Perform automated analysis of proprietary datasets while maintaining complete data residency control

#### Regulated Industries

* Healthcare organizations can leverage AI for medical record analysis and clinical decision support while ensuring HIPAA compliance
* Financial institutions can implement AI-driven fraud detection and risk assessment without compromising customer data privacy
* Government agencies can utilize LLMs for document processing and intelligence analysis within secure, air-gapped environments

#### Development and Testing

* Create secure AI development environments for testing and prototyping without external dependencies
* Enable developers to experiment with AI features in isolated environments before production deployment

#### Operational Efficiency

* Deploy AI-powered chatbots and virtual assistants that can access internal knowledge bases and systems
* Automate document generation, code review, and technical documentation while maintaining security standards

### Setup Use Cases

#### [Single User Setup](./docker-single-user-setup/README.md)

The single user setup should be followed when the following requirements for the project that user is working on are fulfilled:

* User wants to experiment with local LLM
* User knows how to operate Docker/Podman
* User cannot/do not access any commercially available LLM (e.g. Claude.AI, OpenAI ChatGPT, etc.)
* User has a powerful(-enough) CPU/GPU to host an LLM.

#### [Small Team Setup](./docker-small-team-setup/README.md)

> [!TIP]
> As a rule of thumb, if you're a team of *3-10* people, you're a small enough team to use this setup.

The small team setup should be followed when you need to work together within a team, and have the following requirements:

* Team is not allowed to use any commercially available LLM (e.g. Claude.AI, OpenAI ChatGPT, etc.)
* Team is allowed to have shared model access
* Team is allowed to have shared data access
* Team has access to a shared server with powerful CPU/GPUs
* No need to have an extremely strict "Need to know" role-based access control

If you fulfill the requirements above, then run the small team setup.

#### [Enterprise Setup](./docker-enterprise-setup/README.md)

> [!NOTE]
> In the setup, we've only setup for 3 departments, but we can expand it further if we need to.

> [!WARNING]
> As of July 28th 2025, the Enterprise Setup has not been experimented on with alpha users.

The enterprise setup is the most complex setup which would require more compliant Information Security environment, as the data access needs to be separated between users of different roles. So the requirements are the following:

* Users are not allowed to access or get any information from users from a different department. (Need-to-know Role-Based Access Control)
* LLMs are not allowed to be shared cross departments
* Database of knowledge is not allowed to be shared cross departments
* Environment needs to be compliant to standards such as GDPR
* High security requirements

## Linked Projects

* [Local Ollama PowerShell Wrapper API](https://github.com/adjiap/local-ollama-powershell-wrapper-api)
* [Local Ollama Python Wrapper API](https://github.com/adjiap/local-ollama-python-wrapper-api)

## References

<sup>[1]</sup> https://docs.openwebui.com/

## Acknowledgements
* [Ollama](https://github.com/ollama/ollama)
* [Open WebUI](https://github.com/open-webui/open-webui)
